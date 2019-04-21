from .configuration import config
from .jsonapi import JsonApi


class Vault(JsonApi):

    def __init__(self, endpoint):
        super().__init__(endpoint + '/v1/')

    def init(self):
        return self.put('sys/init', {
            'secret_shares': 1,
            'secret_threshold': 1,
        })


vault = Vault(config.vault_url)
