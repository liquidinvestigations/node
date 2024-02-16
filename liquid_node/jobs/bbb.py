from liquid_node import jobs


class BBB(jobs.Job):
    name = 'bbb'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'bbb'
    stage = 1
    vault_secret_keys = [
        "liquid/bbb/bbb.postgres",
        "liquid/bbb/bbb.secret_key_base",
    ]
    core_oauth_apps = [
        {
            'name': 'bbb',
            'subdomain': 'bbb',
            'vault_path': 'liquid/bbb/auth.oauth2',
            'callback': '/auth/openid_connect/callback',
            'algo': 'HS256',
            'noskip': True,
        },
    ]

