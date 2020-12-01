from liquid_node import jobs


class Dokuwiki(jobs.Job):
    name = 'dokuwiki'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'dokuwiki'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'dokuwiki',
            'vault_path': 'liquid/dokuwiki/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    vault_secret_keys = [
    ]
    generate_oauth2_proxy_cookie = True


class Proxy(jobs.Job):
    name = 'dokuwiki-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'dokuwiki'
    stage = 4
