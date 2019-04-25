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
            for job in ['liquid', 'hoover', 'hoover-ui']
        ]

        self.ini = configparser.ConfigParser()
        self.ini.read(self.root / 'liquid.ini')

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

        self.liquid_debug = self.ini.getboolean('liquid', 'debug', fallback=False)

        self.mount_local_repos = self.ini.getboolean('liquid', 'mount_local_repos', fallback=False)

        self.hoover_repos_path = self.ini.get('liquid', 'hoover_repos_path', fallback=None)

        self.liquidinvestigations_repos_path = self.ini.get('liquid', 'liquidinvestigations_repos_path', fallback=None)

        self.liquid_volumes = self.ini.get('liquid', 'volumes', fallback=str(self.root / 'volumes'))

        self.liquid_collections = self.ini.get('liquid', 'collections', fallback=str(self.root / 'collections'))

        self.liquid_http_port = self.ini.get('liquid', 'http_port', fallback='80')

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

    @classmethod
    def _validate_collection_name(self, name):
        if not name.islower():
            raise ValueError(f'''Invalid collection name "{name}"!

Collection names must start with lower case letters and must contain only
lower case letters and digits.
''')


config = Configuration()
