from pathlib import Path

from liquid_node import jobs


class Nextcloud(jobs.Job):
    def __init__(self, name, job_config, config):
        self.name = 'nextcloud-instance-2'
        self.template =  Path(__file__).parent.resolve() / f'templates/{self.name}.nomad'
        self.app = 'nextcloud-instance-2'
        self.stage = 2
        self.core_oauth_apps = [
            {
                'name': 'nextcloud-instance-2',
                'vault_path': 'liquid/nextcloud-instance-2/auth.oauth2',
                'callback': '/oauth2/callback',
            },
        ]
        self.vault_secret_keys = [
            'liquid/nextcloud-instance-2/nextcloud-instance-2.admin',
            'liquid/nextcloud-instance-2/nextcloud-instance-2.uploads',
            'liquid/nextcloud-instance-2/nextcloud-instance-2.maria',
        ]
        self.generate_oauth2_proxy_cookie = True
