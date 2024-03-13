from liquid_node import jobs


class Prophecies(jobs.Job):
    name = 'prophecies'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'prophecies'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'prophecies-app',
            'subdomain': 'prophecies',
            'vault_path': 'liquid/prophecies/app.auth.oauth2',
            'callback': '/complete/provider/',
        },
        {
            'name': 'prophecies-authproxy',
            'subdomain': 'prophecies',
            'vault_path': 'liquid/prophecies/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    vault_secret_keys = [
        'liquid/prophecies/session.secret',
        'liquid/prophecies/prophecies.postgres',
    ]
    generate_oauth2_proxy_cookie = True


class Proxy(jobs.Job):
    name = 'prophecies-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'prophecies'
    stage = 5


class Deps(jobs.Job):
    name = 'prophecies-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'prophecies'
    stage = 1
