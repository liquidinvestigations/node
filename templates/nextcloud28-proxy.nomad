{% from '_lib.hcl' import authproxy_group with context -%}

job "nextcloud28-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  ${- authproxy_group(
      'nextcloud28',
      host='nextcloud28.' + liquid_domain,
      upstream_port=config.port_nextcloud28,
      group='nextcloud28',
      redis_id=5
    ) }
}
