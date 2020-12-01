from pathlib import Path

from liquid_node import jobs


class AuthDemo(jobs.Job):
    def __init__(self, name, job_config, config):
        self.name = name
        self.app = self.name
        self.template = Path(__file__).parent.resolve() / f'templates/{name}.nomad'
        self.stage = 2

        self.core_oauth_apps = [
            {
                'name': 'authdemo',
                'vault_path': 'liquid/authdemo/auth.oauth2',
                'callback': '/oauth2/callback',
            },
        ]
        self.vault_secret_keys = []
        self.generate_oauth2_proxy_cookie = True
