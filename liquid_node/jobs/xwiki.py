from liquid_node import jobs


class Xwiki(jobs.Job):
    name = 'xwiki'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'xwiki'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'xwiki-app',
            'subdomain': 'xwiki',
            'vault_path': 'liquid/xwiki/app.auth.oauth2',
            'callback': '/oidc/authenticator/callback',
        },
        {
            'name': 'xwiki-authproxy',
            'subdomain': 'xwiki',
            'vault_path': 'liquid/xwiki/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    vault_secret_keys = [
        'liquid/xwiki/xwiki.postgres',
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
