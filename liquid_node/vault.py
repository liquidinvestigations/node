from urllib.error import HTTPError
import logging

from .configuration import config
from .jsonapi import JsonApi

log = logging.getLogger(__name__)


class Vault(JsonApi):

    def __init__(self, endpoint, token=None):
        super().__init__(endpoint + '/v1/')
        self.token = token

    def request(self, *args, headers=None, **kwargs):
        headers = dict(headers or {})
        if self.token:
            headers['X-Vault-Token'] = self.token
        return super().request(*args, headers=headers, **kwargs)

    def init(self):
        return self.put('sys/init', {
            'secret_shares': 1,
            'secret_threshold': 1,
        })

    def unseal(self, key):
        return self.put('sys/unseal', {'key': key})

    def ensure_engine(self):
        mounts = self.get('sys/mounts')
        if 'liquid/' not in mounts['data']:
            log.info("Creating kv secrets engine `liquid`")
            self.post(f'sys/mounts/liquid', {'type': 'kv'})

    def read(self, path):
        try:
            return self.get(f'liquid/{path}')['data']
        except HTTPError as e:
            if e.code == 404:
                return None
            raise

    def set(self, path, payload):
        return self.put(f'liquid/{path}', payload)


vault = Vault(config.vault_url, config.vault_token)
