{% from '_lib.hcl' import authproxy_group with context -%}

job "collabora-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  ${- authproxy_group(
    'collabora',
    host='collabora.' + liquid_domain,
    upstream_port=config.port_collabora,
    group='collabora',
    redis_id=7
    ) }
}
