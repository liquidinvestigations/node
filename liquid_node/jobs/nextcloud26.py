from liquid_node import jobs


class Nextcloud(jobs.Job):
    name = 'nextcloud26'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'nextcloud26-app',
            'subdomain': 'nextcloud26',
            'vault_path': 'liquid/nextcloud26/app.auth.oauth2',
            'callback': '/apps/sociallogin/custom_oauth2/liquid',
        },
        {
            'name': 'nextcloud26-authproxy',
            'subdomain': 'nextcloud26',
            'vault_path': 'liquid/nextcloud26/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    vault_secret_keys = [
        'liquid/nextcloud26/nextcloud.maria',
        'liquid/nextcloud26/nextcloud.admin',
        'liquid/nextcloud26/minio.user',
        'liquid/nextcloud26/minio.password',
        'liquid/nextcloud26/minioext.user',
        'liquid/nextcloud26/minioext.password',
    ]
    generate_oauth2_proxy_cookie = True


class Proxy(jobs.Job):
    name = 'nextcloud26-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud26'
    stage = 4


class Deps(jobs.Job):
    name = 'nextcloud26-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud26'
    stage = 1
