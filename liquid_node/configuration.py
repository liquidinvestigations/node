import time
from collections import OrderedDict
import configparser
from pathlib import Path
from .util import import_string
from .jobs import Job

from liquid_node.jobs import liquid
from liquid_node.jobs import hoover
from liquid_node.jobs import dokuwiki
from liquid_node.jobs import rocketchat
from liquid_node.jobs import nextcloud
from liquid_node.jobs import ci

DOCKER_IMAGES = [
    'liquidinvestigations/core',
    'liquidinvestigations/authproxy',
    'liquidinvestigations/hoover-search',
    'liquidinvestigations/hoover-ui',
    'liquidinvestigations/hoover-snoop2',
    'liquidinvestigations/caboose',
    'liquidinvestigations/liquid-nextcloud',
    'vmck/vmck',
]


class Configuration:

    def __init__(self):
        self.root = Path(__file__).parent.parent.resolve()
        self.templates = self.root / 'templates'

        self.jobs = [
            liquid.Liquid(),
            hoover.Hoover(),
            hoover.Ui(),
            hoover.Migrate(),
            dokuwiki.Dokuwiki(),
            dokuwiki.Migrate(),
            rocketchat.Rocketchat(),
            rocketchat.Migrate(),
            nextcloud.Nextcloud(),
            nextcloud.Migrate(),
        ]

        self.ini = configparser.ConfigParser()
        self.ini.read(self.root / 'liquid.ini')

        self.consul_url = self.ini.get('cluster', 'consul_url', fallback='http://127.0.0.1:8500')
        self.consul_socket = self.ini.get('cluster', 'consul_socket')

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

        self.liquid_volumes = self.ini.get('liquid', 'volumes', fallback=str(self.root / 'volumes'))

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
            self.liquid_http_protocol = 'http'
        self.liquid_core_url = f'{self.liquid_http_protocol}://{self.liquid_domain}'

        self.liquid_2fa = self.ini.getboolean('liquid', 'two_factor_auth', fallback=False)

        self.check_interval = self.ini.get('deploy', 'check_interval', fallback='3s')
        self.check_timeout = self.ini.get('deploy', 'check_timeout', fallback='2s')
        self.wait_max = self.ini.getfloat('deploy', 'wait_max_sec', fallback=300)
        self.wait_interval = self.ini.getfloat('deploy', 'wait_interval', fallback=1)
        self.wait_green_count = self.ini.getint('deploy', 'wait_green_count', fallback=10)

        self.versions = {
            name: self.ini.get('versions', name, fallback='latest')
            for name in DOCKER_IMAGES
        }

        self.ci_enabled = 'ci' in self.ini
        if self.ci_enabled:
            self.ci_runner_capacity = self.ini.getint('ci', 'runner_capacity', fallback=2)
            self.ci_docker_username = self.ini.get('ci', 'docker_username')
            self.ci_docker_password = self.ini.get('ci', 'docker_password')
            self.ci_github_client_id = self.ini.get('ci', 'github_client_id')
            self.ci_github_client_secret = self.ini.get('ci', 'github_client_secret')
            self.ci_github_user_filter = self.ini.get('ci', 'github_user_filter')
            self.jobs.append(ci.Drone())

        self.collections = OrderedDict()
        for key in self.ini:
            if ':' not in key:
                continue

            (cls, name) = key.split(':')

            if cls == 'collection':
                Configuration._validate_collection_name(name)
                self.collections[name] = self.ini[key]

            elif cls == 'job':
                self.jobs.append(self.load_job(name, self.ini[key]))

        self.timestamp = int(time.time())

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

    @classmethod
    def _validate_collection_name(self, name):
        if not name.islower():
            raise ValueError(f'''Invalid collection name "{name}"!

Collection names must start with lower case letters and must contain only
lower case letters and digits.
''')

    def image(self, name):
        assert name in self.versions, f'please add image {name} to DOCKER_IMAGES'
        return f'{name}:{self.versions[name]}'


config = Configuration()
