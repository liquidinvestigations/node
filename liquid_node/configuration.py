import configparser
import time
from distutils.util import strtobool
from pathlib import Path

from .util import import_string
from liquid_node.jobs import ci, Job, liquid, hoover, dokuwiki, rocketchat, \
    nextcloud, hypothesis, codimd


def split_lang_codes(option):
    option = option.strip()
    if not option:
        return []
    return option.split(',')


class Configuration:
    ALL_APPS = ('liquid', 'hoover', 'dokuwiki', 'rocketchat', 'nextcloud',
                'hypothesis', "codimd")
    # The core apps can't be turned off.
    CORE_APPS = ('liquid', 'hoover',)

    def __init__(self):
        self.root = Path(__file__).parent.parent.resolve()
        self.templates = self.root / 'templates'

        self.versions_ini = configparser.ConfigParser()
        self.versions_ini.read(self.root / 'versions.ini')

        self.ini = configparser.ConfigParser()
        self.ini.read(self.root / 'liquid.ini')

        self.default_app_status = self.ini.get('apps', 'default_app_status', fallback='on')

        self.all_jobs = [
            liquid.Liquid(),
            liquid.Ingress(),
            hoover.Hoover(),
            hoover.Ui(),
            hoover.Deps(),
            hoover.Workers(),
            dokuwiki.Dokuwiki(),
            rocketchat.Rocketchat(),
            rocketchat.Migrate(),
            nextcloud.Nextcloud(),
            nextcloud.Migrate(),
            nextcloud.Periodic(),
            hypothesis.Hypothesis(),
            hypothesis.UserSync(),
            codimd.Codimd(),
        ]
        self.enabled_jobs = [job for job in self.all_jobs if self.is_app_enabled(job.app)]
        self.disabled_jobs = [job for job in self.all_jobs if not self.is_app_enabled(job.app)]

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

        self.auth_auto_logout = self.ini.get('liquid', 'auth_auto_logout', fallback='')

        self.liquid_2fa = self.ini.getboolean('liquid', 'two_factor_auth', fallback=False)

        self.elasticsearch_heap_size = self.ini.getint('liquid', 'elasticsearch_heap_size',
                                                       fallback=1024)
        self.elasticsearch_memory_limit = self.ini.getint('liquid', 'elasticsearch_memory_limit',
                                                          fallback=1536)
        self.elasticsearch_data_node_count = self.ini.getint('liquid', 'elasticsearch_data_node_count', fallback=0)  # noqa: E501

        self.tika_count = self.ini.get('liquid', 'tika_count', fallback=1)
        self.tika_memory_limit = self.ini.get('liquid', 'tika_memory_limit', fallback=800)

        self.hypothesis_memory_limit = \
            self.ini.getint('liquid',
                            'hypothesis_memory_limit',
                            fallback=1024)
        self.nextcloud_memory_limit = \
            self.ini.getint('liquid',
                            'nextcloud_memory_limit',
                            fallback=512)

        self.hoover_ratelimit_user = self.ini.get('liquid', 'hoover_ratelimit_user', fallback='30,60')

        self.hoover_authproxy_memory_limit = self.ini.getint('liquid',
                                                             'hoover_authproxy_memory_limit', fallback=400)
        self.hoover_web_memory_limit = self.ini.getint('liquid',
                                                       'hoover_web_memory_limit', fallback=300)
        self.hoover_web_count = self.ini.getint('liquid',
                                                'hoover_web_count', fallback=2)

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

        self.check_interval = self.ini.get('deploy', 'check_interval', fallback='11s')
        self.check_timeout = self.ini.get('deploy', 'check_timeout', fallback='9s')
        self.wait_max = self.ini.getfloat('deploy', 'wait_max_sec', fallback=300)
        self.wait_interval = self.ini.getfloat('deploy', 'wait_interval', fallback=1)
        self.wait_green_count = self.ini.getint('deploy', 'wait_green_count', fallback=8)

        self.ci_enabled = 'ci' in self.ini
        if self.ci_enabled:
            self.ci_runner_capacity = self.ini.getint('ci', 'runner_capacity', fallback=2)
            self.ci_docker_username = self.ini.get('ci', 'docker_username')
            self.ci_docker_password = self.ini.get('ci', 'docker_password')
            self.ci_github_client_id = self.ini.get('ci', 'github_client_id')
            self.ci_github_client_secret = self.ini.get('ci', 'github_client_secret')
            self.ci_github_user_filter = self.ini.get('ci', 'github_user_filter')
            self.ci_docker_registry_address = self.ini.get('ci', 'docker_registry_address', fallback=None)
            self.ci_docker_registry_port = self.ini.get('ci', 'docker_registry_port', fallback=None)
            if self.ci_docker_registry_address and self.ci_docker_registry_port:
                self.ci_docker_registry_env = (
                    f',REGISTRY_ADDRESS:{self.ci_docker_registry_address}'
                    f',REGISTRY_PORT:{self.ci_docker_registry_port}'
                )
            else:
                self.ci_docker_registry_env = ''
            self.enabled_jobs.append(ci.Drone())

        self.snoop_collections = []
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
                })

            elif cls == 'job':
                self.enabled_jobs.append(self.load_job(name, self.ini[key]))

        self.timestamp = int(time.time())

    def image(self, name):
        """Returns the NAME:TAG for a docker image from versions.ini.

        Can be overrided in liquid.ini, same section name.
        """

        assert self.versions_ini.get('versions', name, fallback=None), \
            f'docker tag for {name} not set in versions.ini'
        default_tag = self.versions_ini.get('versions', name)
        image = self.ini.get('versions', name, fallback=default_tag)
        return f'{image}'

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
