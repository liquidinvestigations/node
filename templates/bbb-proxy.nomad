{% from '_lib.hcl' import authproxy_group, group_disk, task_logs with context -%}

job "bbb-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98


  ${- authproxy_group(
      'bbb',
      host='bbb.' + liquid_domain,
      upstream_port=config.port_bbb_gl,
      group='bbb',
      redis_id=6
    ) }
}
