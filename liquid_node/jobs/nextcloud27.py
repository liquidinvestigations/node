from liquid_node import jobs


class Nextcloud(jobs.Job):
    name = 'nextcloud27'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'nextcloud27-app',
            'subdomain': 'nextcloud27',
            'vault_path': 'liquid/nextcloud27/app.auth.oauth2',
            'callback': '/apps/sociallogin/custom_oauth2/liquid',
        },
        {
            'name': 'nextcloud27-authproxy',
            'subdomain': 'nextcloud27',
            'vault_path': 'liquid/nextcloud27/auth.oauth2',
            'callback': '/oauth2/callback',
        },
        {
            'name': 'onlyoffice-app',
            'subdomain': 'onlyoffice',
            'vault_path': 'liquid/onlyoffice/app.auth.oauth2',
            'callback': '/login/liquid/callback',
        },
        {
            'name': 'onlyoffice-authproxy',
            'subdomain': 'onlyoffice',
            'vault_path': 'liquid/onlyoffice/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    vault_secret_keys = [
        'liquid/nextcloud27/nextcloud.maria',
        'liquid/nextcloud27/nextcloud.admin',
        'liquid/nextcloud27/minio.user',
        'liquid/nextcloud27/minio.password',
        'liquid/nextcloud27/minioext.user',
        'liquid/nextcloud27/minioext.password',
    ]
    generate_oauth2_proxy_cookie = True


class Onlyoffice(jobs.Job):
    name = 'onlyoffice'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'onlyoffice'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'onlyoffice-app',
            'subdomain': 'onlyoffice',
            'vault_path': 'liquid/onlyoffice/app.auth.oauth2',
            'callback': '/login/liquid/callback',
        },
        {
            'name': 'onlyoffice-authproxy',
            'subdomain': 'onlyoffice',
            'vault_path': 'liquid/onlyoffice/auth.oauth2',
            'callback': '/oauth2/callback',
        },
    ]
    generate_oauth2_proxy_cookie = True


class Proxy(jobs.Job):
    name = 'nextcloud27-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud27'
    stage = 4


class OfficeProxy(jobs.Job):
    name = 'onlyoffice-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud27'
    stage = 5


class Deps(jobs.Job):
    name = 'nextcloud27-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud27'
    stage = 1
