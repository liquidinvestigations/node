from liquid_node import jobs


class Codimd(jobs.Job):
    name = 'codimd'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'codimd'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'codimd-app',
            'vault_path': 'liquid/codimd/app.auth.oauth2',
            'callback': '/auth/oauth2/callback',
        },
        {
            'name': 'codimd-authproxy',
            'vault_path': 'liquid/codimd/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    vault_secret_keys = [
        'liquid/codimd/codimd.session',
        'liquid/codimd/codimd.postgres',
    ]
    generate_oauth2_proxy_cookie = True


class Deps(jobs.Job):
    name = 'codimd-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'codimd'
    stage = 1


class Proxy(jobs.Job):
    name = 'codimd-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'codimd'
    stage = 4
