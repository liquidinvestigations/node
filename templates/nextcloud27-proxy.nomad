{% from '_lib.hcl' import authproxy_group with context -%}

job "nextcloud27-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  ${- authproxy_group(
      'nextcloud27',
      host='nextcloud27.' + liquid_domain,
      upstream_port=config.port_nextcloud27,
      group='nextcloud27',
      redis_id=5
    ) }
}
