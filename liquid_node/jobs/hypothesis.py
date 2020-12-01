from liquid_node import jobs


class Hypothesis(jobs.Job):
    name = 'hypothesis'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hypothesis'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'hypothesis',
            'vault_path': 'liquid/hypothesis/auth.oauth2',
            # the old auth proxy is still running for this service. new one:
            # 'callback': '/oauth2/callback',
            'callback': '/__auth/callback',
        },
    ]
    vault_secret_keys = [
        'liquid/hypothesis/auth.django',
        'liquid/hypothesis/hypothesis.secret_key',
        'liquid/hypothesis/hypothesis.postgres',
    ]
    generate_oauth2_proxy_cookie = True


class Deps(jobs.Job):
    name = 'hypothesis-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hypothesis'
    stage = 1


class UserSync(jobs.Job):
    name = 'hypothesis-usersync'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hypothesis'
    stage = 3


class Proxy(jobs.Job):
    name = 'hypothesis-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hypothesis'
    stage = 4
