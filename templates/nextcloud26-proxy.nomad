{% from '_lib.hcl' import authproxy_group with context -%}

job "nextcloud26-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  ${- authproxy_group(
      'nextcloud26',
      host='nextcloud26.' + liquid_domain,
      upstream_port=config.port_nextcloud26,
      group='nextcloud26',
      redis_id=5
    ) }
}
