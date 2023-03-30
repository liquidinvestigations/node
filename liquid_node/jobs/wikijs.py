from liquid_node import jobs


class Wikijs(jobs.Job):
    name = 'wikijs'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'wikijs'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'wikijs-app',
            'subdomain': 'wikijs',
            'vault_path': 'liquid/wikijs/app.auth.oauth2',
            'callback': '/login/liquid/callback',
        },
        {
            'name': 'wikijs-authproxy',
            'subdomain': 'wikijs',
            'vault_path': 'liquid/wikijs/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    vault_secret_keys = [
        'liquid/wikijs/wikijs.postgres',
        'liquid/wikijs/wikijs.session',
    ]
    generate_oauth2_proxy_cookie = True


class Deps(jobs.Job):
    name = 'wikijs-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    pg_tasks = ['wikijs-pg']
    app = 'wikijs'
    stage = 1


class Proxy(jobs.Job):
    name = 'wikijs-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'wikijs'
    stage = 4
