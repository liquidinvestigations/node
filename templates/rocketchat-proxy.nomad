{% from '_lib.hcl' import authproxy_group with context -%}

job "rocketchat-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 30

  spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

  ${- authproxy_group(
      'rocketchat',
      host='rocketchat.' + liquid_domain,
      upstream='rocketchat-app',
    ) }
}
