{% from '_lib.hcl' import shutdown_delay, authproxy_group, task_logs, group_disk with context -%}

job "bbb-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98


  ${- authproxy_group(
      'bbb',
      host='bbb.' + liquid_domain,
      upstream_port=config.port_bbb_gl,
      group='user',
      redis_id=6,
    ) }
}
