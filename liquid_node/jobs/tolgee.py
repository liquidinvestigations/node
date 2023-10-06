from liquid_node import jobs


class Tolgee(jobs.Job):
    name = 'tolgee'
    app = 'tolgee'
    template = jobs.TEMPLATES / f'{name}.nomad'
    stage = 2
    vault_secret_keys = [
        'liquid/tolgee/jwt.secret',
        'liquid/tolgee/admin.password',
    ]
    def extra_secret_fn(self, vault, config, random_secret):
        vault.set('liquid/tolgee/oauth.github', {
            'client_id': config.tolgee_github_client_id,
            'client_secret': config.tolgee_github_client_secret,
        })
        vault.set('liquid/tolgee/mt.services', {
            'deepl_auth_key': config.tolgee_deepl_auth_key,
            'google_api_key': config.tolgee_google_api_key,
        })
