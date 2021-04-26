from liquid_node import jobs


class Newsleak(jobs.Job):
    name = 'newsleak'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'newsleak'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'newsleak',
            'vault_path': 'liquid/newsleak/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    generate_oauth2_proxy_cookie = True



class Proxy(jobs.Job):
    name = 'newsleak-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'newsleak-ui'
    stage = 4


class Deps(jobs.Job):
    name = 'newsleak-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'newsleak-ui'
    stage = 1
