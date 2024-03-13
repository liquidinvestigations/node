from liquid_node import jobs


class Grist(jobs.Job):
    name = 'grist'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'grist'
    stage = 3
    core_oauth_apps = [
        # {
        #     'name': 'grist-app',
        #     'subdomain': 'grist',
        #     'vault_path': 'liquid/grist/app.auth.oauth2',
        #     'callback': '/oauth2/callback',
        # },
        {
            'name': 'grist-authproxy',
            'subdomain': 'grist',
            'vault_path': 'liquid/grist/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    vault_secret_keys = [
        'liquid/grist/session.secret',
        'liquid/grist/grist.postgres',
        "liquid/grist/minio.user",
        "liquid/grist/minio.password",
    ]
    generate_oauth2_proxy_cookie = True


class Proxy(jobs.Job):
    name = 'grist-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'grist'
    stage = 4


class Deps(jobs.Job):
    name = 'grist-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'grist'
    stage = 1


class Migrate(jobs.Job):
    name = 'grist-migrate'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'grist'
    stage = 2
