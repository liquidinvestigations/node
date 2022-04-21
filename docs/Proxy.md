# Proxy

Our current proxy is based on `https://github.com/oauth2-proxy/oauth2-proxy` and sets the following environment variable:

Environment variables specific for the liquid provider:
- `LIQUID_HTTP_PROTOCOL` - must be set to `http` or `https`
- `LIQUID_DOMAIN` - domain name of the auth provider service, e.g. liquid.example.org 

Others relevant environment variables for the proxy Docker container:

- `OAUTH2_PROXY_WHITELIST_DOMAINS` - allows domains for redirection after authentication. Prefix domain with a . to allow subdomains, e.g .liquid.example.org
- `OAUTH2_PROXY_SSL_INSECURE_SKIP_VERIFY` and `OAUTH2_PROXY_SSL_UPSTREAM_INSECURE_SKIP_VERIFY` are both set to true to skip validation of certificates when using  HTTPS providers and HTTPS upstreams, in case the domain has no valid certificate.
- `OAUTH2_PROXY_SET_XAUTHREQUEST` set X-Auth-Request-User

- ` OAUTH2_PROXY_COOKIE_HTTPONLY and OAUTH2_PROXY_COOKIE_SECURE` are both disable to allow both http and https cookies.
- ` OAUTH2_PROXY_EMAIL_DOMAINS` is set to * to allow any email domain to authenticate.
