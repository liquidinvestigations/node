import json
import logging
from urllib.request import Request, urlopen


log = logging.getLogger(__name__)


class JsonApi:

    def __init__(self, endpoint):
        self.endpoint = endpoint

    def request(self, method, url, data=None, headers=None):
        """Makes a request against the JSON endpoint

        :param method: the request method
        :param url: the path in the JSON API
        :param data: the request body
        :type data: bytes|str
        """
        req_url = f'{self.endpoint}{url}'
        req_headers = dict(headers or {})
        req_body = None

        if data is not None:
            if isinstance(data, bytes):
                req_body = data

            else:
                req_headers['Content-Type'] = 'application/json'
                req_body = json.dumps(data).encode('utf8')

        req = Request(
            req_url,
            req_body,
            req_headers,
            method=method,
        )

        with urlopen(req) as res:
            if res.status == 200:
                res_body = json.load(res)
                return res_body

    def get(self, url):
        return self.request('GET', url)

    def post(self, url, data):
        return self.request('POST', url, data)

    def put(self, url, data):
        return self.request('PUT', url, data)

    def delete(self, url):
        return self.request('DELETE', url)
