{% from '_lib.hcl' import shutdown_delay, authproxy_group, task_logs, group_disk with context -%}

job "prophecies-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98


  ${- authproxy_group(
      'prophecies',
      host='prophecies.' + liquid_domain,
      upstream_port=config.port_prophecies_nginx,
      group='prophecies',
      redis_id=12,
    ) }
}
