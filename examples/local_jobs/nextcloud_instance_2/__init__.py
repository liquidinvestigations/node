from pathlib import Path

from liquid_node import jobs


class Nextcloud(jobs.Job):
    def __init__(self, name, job_config, config):
        self.template = Path(__file__).parent.resolve() / 'templates/nextcloud-instance-2.nomad'
        self.name = 'nextcloud-instance-2'
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
        self.custom_homepage_config = {
            'id': self.name,
            'title': 'Nextcloud (Instance 2)',
            'url': config.app_url(self.name),
            'enabled': True,
            'description': 'is a different zone (with different permissions) to upload files.',
            'adminOnly': False,
            'version': config.version('nextcloud'),
            'redis_id': 9,
        }
