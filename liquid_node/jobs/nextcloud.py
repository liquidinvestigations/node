from liquid_node import jobs


class Nextcloud(jobs.Job):
    name = 'nextcloud'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'nextcloud',
            'vault_path': 'liquid/nextcloud/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    vault_secret_keys = [
        'liquid/nextcloud/nextcloud.maria',
        'liquid/nextcloud/nextcloud.admin',
        'liquid/nextcloud/minio.user',
        'liquid/nextcloud/minio.password',
        'liquid/nextcloud/minioext.user',
        'liquid/nextcloud/minioext.password',
    ]
    generate_oauth2_proxy_cookie = True


class Proxy(jobs.Job):
    name = 'nextcloud-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'
    stage = 5


class Deps(jobs.Job):
    name = 'nextcloud-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'
    stage = 1
