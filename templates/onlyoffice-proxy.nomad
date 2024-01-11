{% from '_lib.hcl' import authproxy_group with context -%}

job "onlyoffice-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  ${- authproxy_group(
      'onlyoffice',
      host='onlyoffice.' + liquid_domain,
      upstream_port=config.port_onlyoffice,
      group='onlyoffice',
      redis_id=7
    ) }
}
