import configparser
import os
import subprocess
import time
from distutils.util import strtobool
from pathlib import Path

from .util import import_string
from .docker import docker
from liquid_node.jobs import Job, liquid, hoover, dokuwiki, rocketchat, \
    nextcloud, hypothesis, codimd, ci


def split_lang_codes(option):
    option = option.strip()
    if not option:
        return []
    return option.split(',')


class Configuration:
    ALL_APPS = ('hoover', 'dokuwiki', 'rocketchat', 'nextcloud',
                'hypothesis', 'codimd',)
    # The core apps can't be turned off.
    CORE_APPS = ('liquid', 'ingress',)

    APP_TITLE = {
        'dokuwiki': 'DokuWiki',
        'rocketchat': "Rocket.Chat",
        'codimd': "CodiMD",
    }

    APP_DESCRIPTION = {
        'hoover': 'is a search app.',
        'hypothesis': 'is an annotation system.',
        'dokuwiki': 'is a wiki system used as a knowledge base for processed information.',
        'codimd': 'is a real-time collaboration pad.',
        'nextcloud': 'has a file share system and a contact list of users.',
        'rocketchat': 'is the chat app.'
    }

    ALL_JOBS = [
        liquid.Liquid(),
        liquid.Ingress(),
        hoover.Hoover(),
        hoover.Deps(),
        hoover.Workers(),
        hoover.Proxy(),
        hoover.Nginx(),
        dokuwiki.Dokuwiki(),
        dokuwiki.Proxy(),
        rocketchat.Rocketchat(),
        rocketchat.Deps(),
        rocketchat.Migrate(),
        rocketchat.Proxy(),
        nextcloud.Nextcloud(),
        nextcloud.Deps(),
        nextcloud.Migrate(),
        nextcloud.Periodic(),
        nextcloud.Proxy(),
        hypothesis.Hypothesis(),
        hypothesis.Deps(),
        hypothesis.UserSync(),
        hypothesis.Proxy(),
        codimd.Codimd(),
        codimd.Deps(),
        codimd.Proxy(),
        ci.Drone(),
        ci.Deps(),
        ci.DroneWorkers(),
    ]

    def __init__(self):
        self.root = Path(__file__).parent.parent.resolve()
        self.templates = self.root / 'templates'

        self.ini = configparser.ConfigParser()
        self.ini.read(self.root / 'liquid.ini')

        self.versions_ini = configparser.ConfigParser()
        if (self.root / 'versions.ini').is_file():
            self.versions_ini.read(self.root / 'versions.ini')

        self.version_track = self.ini.get('liquid', 'version_track', fallback='production')
        self.track_ini = configparser.ConfigParser()
        assert (self.root / (self.version_track + '-versions.ini')).is_file(), \
            'invalid version_track'
        self.track_ini.read(self.root / (self.version_track + '-versions.ini'))

        self.cluster_root_path = self.ini.get('cluster', 'cluster_path', fallback=None)
        self.consul_url = self.ini.get('cluster', 'consul_url', fallback='http://127.0.0.1:8500')

        self.vault_url = self.ini.get('cluster', 'vault_url', fallback='http://127.0.0.1:8200')

        self.vault_token = None

        vault_secrets_path = self.ini.get('cluster', 'vault_secrets', fallback=None)
        if vault_secrets_path:
            secrets = configparser.ConfigParser()
            secrets.read(self.root / vault_secrets_path)
            self.vault_token = secrets.get('vault', 'root_token', fallback=None)

        self.nomad_url = self.ini.get('cluster', 'nomad_url', fallback='http://127.0.0.1:4646')

        self.liquid_domain = self.ini.get('liquid', 'domain', fallback='localhost')

        default_title = ' '.join(map(str.capitalize, self.liquid_domain.split('.')))
        self.liquid_title = self.ini.get('liquid', 'title', fallback=default_title)

        self.liquid_debug = self.ini.getboolean('liquid', 'debug', fallback=False)

        self.mount_local_repos = self.ini.getboolean('liquid', 'mount_local_repos', fallback=False)

        hoover_repos_path = self.ini.get('liquid', 'hoover_repos_path',
                                         fallback=str((self.root / 'repos' / 'hoover')))
        self.hoover_repos_path = str(Path(hoover_repos_path).resolve())

        li_repos_path = self.ini.get('liquid', 'liquidinvestigations_repos_path',
                                     fallback=str((self.root / 'repos' / 'liquidinvestigations')))
        self.liquidinvestigations_repos_path = str(Path(li_repos_path).resolve())

        h_repos_path = self.ini.get('liquid', 'hypothesis_repos_path',
                                    fallback=str((self.root / 'repos' / 'hypothesis')))
        self.hypothesis_repos_path = str(Path(h_repos_path).resolve())

        self.liquid_volumes = self.ini.get('liquid', 'volumes', fallback=None)

        self.liquid_collections = self.ini.get('liquid', 'collections',
                                               fallback=str(self.root / 'collections'))

        self.liquid_http_port = self.ini.get('liquid', 'http_port', fallback='80')

        self.https_enabled = 'https' in self.ini
        if self.https_enabled:
            self.liquid_http_protocol = 'https'
            self.liquid_https_port = self.ini.get('https', 'https_port', fallback='443')
            self.https_acme_email = self.ini.get('https', 'acme_email')
            self.https_acme_caServer = self.ini.get(
                'https',
                'acme_caServer',
                fallback="https://acme-staging-v02.api.letsencrypt.org/directory"
            )

        else:
            self.liquid_http_protocol = self.ini.get('liquid', 'http_protocol_override', fallback='http')
        self.liquid_core_url = f'{self.liquid_http_protocol}://{self.liquid_domain}'

        self.auth_staff_only = self.ini.getboolean('liquid', 'auth_staff_only', fallback=False)

        self.auth_auto_logout = self.ini.get('liquid', 'auth_auto_logout', fallback='2400h')

        self.liquid_2fa = self.ini.getboolean('liquid', 'two_factor_auth', fallback=False)

        self.elasticsearch_heap_size = self.ini.getint('liquid', 'elasticsearch_heap_size',
                                                       fallback=1024)
        self.elasticsearch_memory_limit = self.ini.getint('liquid', 'elasticsearch_memory_limit',
                                                          fallback=1536)
        self.elasticsearch_data_node_count = self.ini.getint('liquid', 'elasticsearch_data_node_count', fallback=0)  # noqa: E501

        self.tika_count = self.ini.getint('liquid', 'tika_count', fallback=1)
        self.tika_memory_limit = self.ini.getint('liquid', 'tika_memory_limit', fallback=800)

        self.hypothesis_memory_limit = \
            self.ini.getint('liquid',
                            'hypothesis_memory_limit',
                            fallback=1024)
        self.nextcloud_memory_limit = \
            self.ini.getint('liquid',
                            'nextcloud_memory_limit',
                            fallback=512)

        self.hoover_ratelimit_user = self.ini.get('liquid', 'hoover_ratelimit_user', fallback='100,13')

        self.hoover_web_memory_limit = self.ini.getint('liquid',
                                                       'hoover_web_memory_limit', fallback=300)
        self.hoover_web_count = self.ini.getint('liquid',
                                                'hoover_web_count', fallback=1)
        self.rocketchat_show_login_form = self.ini.getboolean('liquid', 'rocketchat_show_login_form', fallback=True)  # noqa: E501

        self.hoover_ui_override_server = self.ini.get('liquid', 'hoover_ui_override_server', fallback='')
        self.hoover_es_max_concurrent_shard_requests = self.ini.getint(
            'liquid', 'hoover_es_max_concurrent_shard_requests', fallback=''
        )
        self.hoover_ui_force_pull = self.ini.getboolean('liquid', 'hoover_ui_force_pull', fallback=False)
        self.hoover_ui_agg_split = self.ini.getint('liquid', 'hoover_ui_agg_split', fallback=1)
        self.hoover_ui_search_retry = self.ini.getint('liquid', 'hoover_ui_search_retry', fallback=1)

        self.snoop_workers_enabled = self.ini.getboolean('snoop', 'enable_workers', fallback=True)
        self.snoop_min_workers_per_node = self.ini.getint('snoop', 'min_workers_per_node', fallback=2)
        self.snoop_max_workers_per_node = self.ini.getint('snoop', 'max_workers_per_node', fallback=4)
        self.snoop_cpu_count_multiplier = self.ini.getfloat('snoop', 'worker_cpu_count_multiplier', fallback=0.85)  # noqa: E501

        self.snoop_rabbitmq_memory_limit = self.ini.getint('snoop', 'rabbitmq_memory_limit', fallback=700)
        self.snoop_postgres_memory_limit = self.ini.getint('snoop', 'postgres_memory_limit', fallback=1400)
        self.snoop_postgres_max_connections = self.ini.getint('snoop', 'postgres_max_connections', fallback=250)  # noqa: E501
        self.snoop_worker_memory_limit = 500 * (2 + self.snoop_min_workers_per_node)
        self.snoop_worker_hard_memory_limit = 5000 * (2 + self.snoop_max_workers_per_node)
        self.snoop_worker_cpu_limit = 1500 * self.snoop_min_workers_per_node
        self.snoop_max_result_window = self.ini.getint('snoop', 'max_result_window', fallback=10000)
        self.snoop_refresh_interval = self.ini.get('snoop', 'refresh_interval', fallback="6s")

        self.check_interval = self.ini.get('deploy', 'check_interval', fallback='24s')
        self.check_timeout = self.ini.get('deploy', 'check_timeout', fallback='20s')
        self.wait_max = self.ini.getfloat('deploy', 'wait_max_sec', fallback=300)
        self.wait_interval = self.ini.getfloat('deploy', 'wait_interval', fallback=4)
        self.wait_green_count = self.ini.getint('deploy', 'wait_green_count', fallback=6)

        self.ci_enabled = 'ci' in self.ini
        if self.ci_enabled:
            self.ci_runner_capacity = self.ini.getint('ci', 'runner_capacity', fallback=4)
            self.ci_docker_username = self.ini.get('ci', 'docker_username')
            self.ci_docker_password = self.ini.get('ci', 'docker_password')
            self.ci_github_client_id = self.ini.get('ci', 'github_client_id')
            self.ci_github_client_secret = self.ini.get('ci', 'github_client_secret')
            self.ci_github_user_filter = self.ini.get('ci', 'github_user_filter')

            self.ci_target_hostname = self.ini.get('ci', 'target_hostname')
            self.ci_target_username = self.ini.get('ci', 'target_username')
            self.ci_target_password = self.ini.get('ci', 'target_password')
            self.ci_target_port = self.ini.get('ci', 'target_port')

        self.default_app_status = self.ini.get('apps', 'default_app_status', fallback='on')
        self.all_jobs = list(self.ALL_JOBS)
        self.enabled_jobs = [job for job in self.all_jobs if self.is_app_enabled(job.app)]
        self.disabled_jobs = [job for job in self.all_jobs if not self.is_app_enabled(job.app)]

        self.image_keys = set(self.track_ini['versions']) | \
            (set(self.versions_ini['versions']) if 'versions' in self.versions_ini.sections() else set()) | \
            (set(self.ini['versions']) if 'versions' in self.ini.sections() else set())
        self.images = set(self._image(c) for c in self.image_keys)

        self.snoop_collections = []

        # load collections and extra jobs
        for key in self.ini:
            if ':' not in key:
                continue

            (cls, name) = key.split(':')

            if cls == 'collection':
                Configuration._validate_collection_name(name)
                self.snoop_collections.append({
                    'name': name,
                    'process': self.ini.getboolean(key, 'process', fallback=False),
                    'sync': self.ini.getboolean(key, 'sync', fallback=False),
                    'ocr_languages': split_lang_codes(self.ini.get(key, 'ocr_languages', fallback='')),
                    'max_result_window': self.ini.getint(
                        key,
                        'max_result_window',
                        fallback=self.snoop_max_result_window
                    ),
                    'refresh_interval': self.ini.getint(
                        key,
                        'refresh_interval',
                        fallback=self.snoop_refresh_interval),
                })

            elif cls == 'job':
                self.enabled_jobs.append(self.load_job(name, self.ini[key]))

        self.timestamp = int(time.time())

        self.liquid_apps = []
        for app in self.ALL_APPS:
            self.liquid_apps.append({
                'id': app,
                'title': self.APP_TITLE.get(app) or app.title(),
                'url': self.app_url(app),
                'enabled': self.is_app_enabled(app),
                'description': self.APP_DESCRIPTION[app],
                'adminOnly': False,
                'version': self.version(app),
            })
        self.liquid_version = self.get_node_version()
        self.liquid_core_version = self.version('liquid-core')

        self.liquid_apps.append({
            'id': "nextcloud-admin",
            'title': "Nextcloud Admin",
            'url': self.app_url('nextcloud') + "/index.php/login?autologin=admin",
            'enabled': self.is_app_enabled('nextcloud'),
            'description': "will log you in as the Nextcloud admin user. "
            "You may need to log out of Nextcloud first.",
            'adminOnly': True,
            'version': '',
        })

    def get_node_version(self):
        try:
            return subprocess.check_output(['git', 'describe', '--tags'], shell=False).decode().strip()
        except subprocess.CalledProcessError:
            return os.getenv('LIQUID_VERSION', 'unknown version')

    def version(self, name):
        def tag(name):
            return self._image(name).split(':', 1)[1]

        if name == 'hoover':
            search = tag('hoover-search')
            snoop = tag('hoover-snoop2')
            ui = tag('hoover-ui')
            return f'search: {search},  snoop: {snoop}, ui: {ui}'

        if name == 'hypothesis':
            h = tag('hypothesis-h')
            client = tag('h-client')
            return f'h: {h},  client: {client}'

        if name in ['dokuwiki', 'nextcloud']:
            return tag('liquid-' + name)

        return tag(name)

    def _image(self, name):
        """Returns the NAME:TAG for a docker image from versions.ini.

        Can be overrided in liquid.ini, same section name.
        """

        for x in [self.ini, self.versions_ini, self.track_ini]:
            val = x.get('versions', name, fallback=None)
            if val:
                return val.strip()
        else:
            raise RuntimeError('image does not exist: ' + name)

    def image(self, name):
        """Returns the NAME@SHA1 for a docker image from the docker system."""
        return docker.image_digest(self._image(name))

    def load_job(self, name, job_config):
        if 'template' in job_config:
            job = Job()
            job.name = name
            job.template = self.root / job_config['template']
            return job

        if 'loader' in job_config:
            job_loader = import_string(job_config['loader'])
            return job_loader(name, job_config, self)

        raise RuntimeError("A job needs `template` or `loader`")

    def app_url(self, name):
        return f'{self.liquid_http_protocol}://{name}.{self.liquid_domain}'

    def is_app_enabled(self, app_name):
        if app_name == 'hoover-workers':
            return self.snoop_workers_enabled and self.is_app_enabled('hoover')
        if app_name == 'ci':
            return self.ci_enabled
        return app_name in Configuration.CORE_APPS or \
            self.ini.getboolean('apps', app_name, fallback=strtobool(self.default_app_status))

    @classmethod
    def _validate_collection_name(self, name):
        if not name.islower():
            raise ValueError(f'''Invalid collection name "{name}"!

Collection names must start with lower case letters and must contain only
lower case letters and digits.
''')


config = Configuration()
