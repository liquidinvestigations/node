from liquid_node import jobs


class Xwiki(jobs.Job):
    name = 'xwiki'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'xwiki'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'xwiki',
            'subdomain': 'wiki3',
            'vault_path': 'liquid/xwiki/app.auth.oauth2',
            'callback': '/oidc/authenticator/callback',
            'algo': 'HS256'
        },
        {
            'name': 'xwiki-authproxy',
            'subdomain': 'wiki3',
            'vault_path': 'liquid/xwiki/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    vault_secret_keys = [
        'liquid/xwiki/xwiki.postgres',
        'liquid/xwiki/xwiki.superadmin'
    ]
    generate_oauth2_proxy_cookie = True


class Deps(jobs.Job):
    name = 'xwiki-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    pg_tasks = ['xwiki-pg']
    app = 'xwiki'
    stage = 1


class Proxy(jobs.Job):
    name = 'xwiki-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'xwiki'
    stage = 5


class Setup(jobs.Job):
    name = 'xwiki-setup'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'xwiki'
    stage = 5
