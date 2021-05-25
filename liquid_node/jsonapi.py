import json
import logging
from urllib.error import HTTPError
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
            if res.status >= 200 and res.status < 300:
                content = res.read()
                content_type = res.headers.get('Content-Type') or ""
                if content_type.startswith('application/json') and len(content):
                    return json.loads(content)
                else:
                    return None
            else:
                raise HTTPError(url, res.status, res.msg, res.headers, res)

    def get(self, url, data=None):
        return self.request('GET', url, data)

    def post(self, url, data=None):
        return self.request('POST', url, data)

    def put(self, url, data):
        return self.request('PUT', url, data)

    def delete(self, url):
        return self.request('DELETE', url)
