{% from '_lib.hcl' import shutdown_delay, authproxy_group, task_logs, group_disk with context -%}

job "rocketchat-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98


  ${- authproxy_group(
      'rocketchat',
      host='rocketchat.' + liquid_domain,
      upstream='rocketchat-app',
      group='rocketchat',
      redis_id=5
    ) }
}