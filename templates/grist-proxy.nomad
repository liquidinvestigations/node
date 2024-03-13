{% from '_lib.hcl' import shutdown_delay, authproxy_group, task_logs, group_disk with context -%}

job "grist-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98


  ${- authproxy_group(
      'grist',
      host='grist.' + liquid_domain,
      upstream_port=config.port_grist_web,
      group='grist',
      redis_id=11,
    ) }
}
