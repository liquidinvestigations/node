from liquid_node import jobs


class Nextcloud(jobs.Job):
    name = 'nextcloudpublic'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloudpublic'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'nextcloudpublic',
            'vault_path': 'liquid/nextcloudpublic/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    vault_secret_keys = [
        'liquid/nextcloudpublic/nextcloud.admin',
        'liquid/nextcloudpublic/nextcloud.uploads',
        'liquid/nextcloudpublic/nextcloud.maria',
    ]
    generate_oauth2_proxy_cookie = True


class Proxy(jobs.Job):
    name = 'nextcloudpublic-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloudpublic'
    stage = 4


class Deps(jobs.Job):
    name = 'nextcloudpublic-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloudpublic'
    stage = 1
