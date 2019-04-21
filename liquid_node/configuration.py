from collections import OrderedDict
import configparser
import os
from pathlib import Path


class Configuration:

    def __init__(self):
        self.root = Path(__file__).parent.parent.resolve()
        self.templates = self.root / 'templates'

        self.jobs = [
            (job, self.templates / f'{job}.nomad')
            for job in ['hoover', 'hoover-ui', 'liquid']
        ]

        self.ini = configparser.ConfigParser()
        self.ini.read(self.root / 'liquid.ini')

        self.consul_url = self.get(
            'CONSUL_URL',
            'cluster.consul_url',
            'http://127.0.0.1:8500',
        )

        self.vault_url = self.get(
            'VAULT_URL',
            'cluster.vault_url',
            'http://127.0.0.1:8200',
        )

        self.nomad_url = self.get(
            'NOMAD_URL',
            'cluster.nomad_url',
            'http://127.0.0.1:4646',
        )

        self.liquid_domain = self.get(
            'LIQUID_DOMAIN',
            'liquid.domain',
            'localhost',
        )

        self.liquid_debug = self.get(
            'LIQUID_DEBUG',
            'liquid.debug',
            '',
        )

        self.mount_local_repos = 'false' != self.get(
            'LIQUID_MOUNT_LOCAL_REPOS',
            'liquid.mount_local_repos',
            'false',
        )

        self.hoover_repos_path = self.get(
            'LIQUID_HOOVER_REPOS_PATH',
            'liquid.hoover_repos_path',
            None,
        )

        self.liquidinvestigations_repos_path = self.get(
            'LIQUID_LIQUIDINVESTIGATIONS_REPOS_PATH',
            'liquid.liquidinvestigations_repos_path',
            None,
        )

        self.liquid_volumes = self.get(
            'LIQUID_VOLUMES',
            'liquid.volumes',
            str(self.root / 'volumes'),
        )

        self.liquid_collections = self.get(
            'LIQUID_COLLECTIONS',
            'liquid.collections',
            str(self.root / 'collections'),
        )

        self.liquid_http_port = self.get(
            'LIQUID_HTTP_PORT',
            'liquid.http_port',
            '80',
        )

        self.collections = OrderedDict()
        for key in self.ini:
            if ':' not in key:
                continue

            (cls, name) = key.split(':')

            if cls == 'collection':
                Configuration._validate_collection_name(name)
                self.collections[name] = self.ini[key]

            elif cls == 'job':
                job_config = self.ini[key]
                self.jobs.append((name, self.root / job_config['template']))

    def get(self, env_key, ini_path, default=None):
        if env_key and os.environ.get(env_key):
            return os.environ[env_key]

        (section_name, key) = ini_path.split('.')
        if section_name in self.ini and key in self.ini[section_name]:
            return self.ini[section_name][key]

        return default

    @classmethod
    def _validate_collection_name(self, name):
        if not name.islower():
            raise ValueError(f'''Invalid collection name "{name}"!

Collection names must start with lower case letters and must contain only
lower case letters and digits.
''')


config = Configuration()
