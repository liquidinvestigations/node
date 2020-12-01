from liquid_node import jobs


class Rocketchat(jobs.Job):
    name = 'rocketchat'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'rocketchat'
    stage = 3
    core_oauth_apps = [
        {
            'name': 'rocketchat-authproxy',
            'vault_path': 'liquid/rocketchat/auth.oauth2',
            'callback': '/oauth2/callback',
        },
        {
            'name': 'rocketchat-app',
            'vault_path': 'liquid/rocketchat/app.oauth2',
            'callback': '/_oauth/liquid',
        },
    ]
    vault_secret_keys = [
    ]
    generate_oauth2_proxy_cookie = True

    def extra_secret_fn(self, vault, config, random_secret):
        vault.ensure_secret('liquid/rocketchat/adminuser', lambda: {
            'username': 'rocketchatadmin',
            'pass': random_secret(64),
        })


class Deps(jobs.Job):
    name = 'rocketchat-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'rocketchat'
    stage = 1


class Migrate(jobs.Job):
    name = 'rocketchat-migrate'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'rocketchat'
    stage = 2


class Proxy(jobs.Job):
    name = 'rocketchat-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'rocketchat'
    stage = 4
