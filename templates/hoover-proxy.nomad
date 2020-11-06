{% from '_lib.hcl' import authproxy_group with context -%}

job "hoover-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

  ${- authproxy_group(
      'hoover',
      host='hoover.' + liquid_domain,
      upstream='hoover-nginx'
    ) }
}
