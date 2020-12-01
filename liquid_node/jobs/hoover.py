from liquid_node import jobs


class Hoover(jobs.Job):
    name = 'hoover'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hoover'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'hoover',
            'vault_path': 'liquid/hoover/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    vault_secret_keys = [
        'liquid/hoover/search.django',
        'liquid/hoover/search.postgres',
        'liquid/hoover/snoop.django',
        'liquid/hoover/snoop.postgres',
    ]
    generate_oauth2_proxy_cookie = True


class Workers(jobs.Job):
    name = 'hoover-workers'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hoover-workers'
    stage = 3


class Proxy(jobs.Job):
    name = 'hoover-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hoover'
    stage = 4


class Deps(jobs.Job):
    name = 'hoover-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    pg_tasks = ['search-pg', 'snoop-pg']
    app = 'hoover'
    stage = 1


class Nginx(jobs.Job):
    name = 'hoover-nginx'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hoover'
    stage = 3
