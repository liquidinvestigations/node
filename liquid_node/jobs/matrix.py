from liquid_node import jobs


class Matrix(jobs.Job):
    name = 'matrix'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'matrix'
    stage = 3
    core_oauth_apps = [
        {
            'name': 'matrix-synapse',
            'subdomain': 'matrix',
            'vault_path': 'liquid/matrix/app.auth.oauth2',
            'callback': '/_synapse/client/oidc/callback',
        },
    ]
    generate_oauth2_proxy_cookie = True
    vault_secret_keys = [
        "liquid/matrix/matrix.postgres",
        "liquid/matrix/form.secret",
        "liquid/matrix/maca.secret",
    ]


class Deps(jobs.Job):
    name = 'matrix-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'matrix'
    stage = 1


class Migrate(jobs.Job):
    name = 'matrix-migrate'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'matrix'
    stage = 2
