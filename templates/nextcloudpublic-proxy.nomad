{% from '_lib.hcl' import authproxy_group with context -%}

job "nextcloudpublic-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  ${- authproxy_group(
      'nextcloudpublic',
      host='nextcloudpublic.' + liquid_domain,
      upstream_port=config.port_nextcloudpublic,
      group='nextcloudpublic',
      redis_id=4
    ) }
}
