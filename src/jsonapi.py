import json
import logging
from urllib.error import HTTPError
from urllib.request import Request, urlopen


log = logging.getLogger(__name__)


class JsonApi:

    def __init__(self, endpoint):
        self.endpoint = endpoint

    def request(self, method, url, data=None):
        req_url = f'{self.endpoint}{url}'
        req_headers = {}
        req_body = None

        if data is not None:
            if isinstance(data, bytes):
                req_body = data

            else:
                req_headers['Content-Type'] = 'application/json'
                req_body = json.dumps(data).encode('utf8')

        log.debug('%s %r %r', method, req_url, data)
        req = Request(
            req_url,
            req_body,
            req_headers,
            method=method,
        )

        try:
            with urlopen(req) as res:
                res_body = json.load(res)
                log.debug('response: %r', res_body)
                return res_body

        except HTTPError as e:
            log.error("Error %r: %r", e, e.file.read())
            raise

    def get(self, url):
        return self.request('GET', url)

    def post(self, url, data):
        return self.request('POST', url, data)

    def put(self, url, data):
        return self.request('PUT', url, data)

    def delete(self, url):
        return self.request('DELETE', url)
