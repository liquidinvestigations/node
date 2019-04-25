from .configuration import config
from .jsonapi import JsonApi


class Consul(JsonApi):

    def __init__(self, endpoint):
        super().__init__(endpoint + '/v1/')

    def set_kv(self, key, value):
        assert self.put(f'kv/{key}', value.encode('latin1'))


consul = Consul(config.consul_url)
