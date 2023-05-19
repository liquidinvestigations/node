{% from '_lib.hcl' import authproxy_group with context -%}

job "nextcloud-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  ${- authproxy_group(
      'nextcloud',
      host='nextcloud.' + liquid_domain,
      upstream_port=config.port_nextcloud,
      group='nextcloud',
      redis_id=7
    ) }
}
