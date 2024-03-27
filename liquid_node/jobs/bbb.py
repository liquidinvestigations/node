from liquid_node import jobs


class BBB(jobs.Job):
    name = 'bbb'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'bbb'
    stage = 1
    vault_secret_keys = [
        "liquid/bbb/bbb.postgres",
        "liquid/bbb/bbb.secret_key_base",
    ]
    core_oauth_apps = [
        {
            'name': 'bbb',
            'subdomain': 'bbb',
            'vault_path': 'liquid/bbb/gloauth.oauth2',
            'callback': '/auth/openid_connect/callback',
            'algo': 'HS256',
            'noskip': True,
        },
        {
            'name': 'bbb-authproxy',
            'subdomain': 'bbb',
            'vault_path': 'liquid/bbb/auth.oauth2',
            'callback': '/oauth2/callback',
        }
    ]
    generate_oauth2_proxy_cookie = True


class Proxy(jobs.Job):
    name = 'bbb-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'bbb'
    stage = 4


class Migrate(jobs.Job):
    name = 'bbb-migrate'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'bbb'
    stage = 2
