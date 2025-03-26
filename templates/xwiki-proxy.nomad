{% from '_lib.hcl' import authproxy_group, group_disk, task_logs with context -%}

job "xwiki-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98


  ${- authproxy_group(
      'xwiki',
      host='wiki3.' + liquid_domain,
      upstream_port=config.port_xwiki,
      group='xwiki',
      redis_id=13,
    ) }
}
