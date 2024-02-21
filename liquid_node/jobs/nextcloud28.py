from liquid_node import jobs


class Nextcloud(jobs.Job):
    name = 'nextcloud28'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud28'
    stage = 2
    core_oauth_apps = [
        {
            'name': 'nextcloud28-app',
            'subdomain': 'nextcloud28',
            'vault_path': 'liquid/nextcloud28/app.auth.oauth2',
            'callback': '/apps/sociallogin/custom_oauth2/liquid',
        },
        {
            'name': 'nextcloud28-authproxy',
            'subdomain': 'nextcloud28',
            'vault_path': 'liquid/nextcloud28/auth.oauth2',
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
        'liquid/nextcloud28/nextcloud.maria',
        'liquid/nextcloud28/nextcloud.admin',
        'liquid/nextcloud28/minio.user',
        'liquid/nextcloud28/minio.password',
        'liquid/nextcloud28/minioext.user',
        'liquid/nextcloud28/minioext.password',
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
    name = 'nextcloud28-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud28'
    stage = 4


class OfficeProxy(jobs.Job):
    name = 'onlyoffice-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud28'
    stage = 5


class Deps(jobs.Job):
    name = 'nextcloud28-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud28'
    stage = 1
