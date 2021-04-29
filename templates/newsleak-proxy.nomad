{% from '_lib.hcl' import shutdown_delay, authproxy_group, continuous_reschedule, set_pg_password_template, task_logs, group_disk with context -%}

job "newsleak-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  ${- authproxy_group(
      'newsleak',
      host='newsleak.' + liquid_domain,
      upstream='newsleak-ui',
    ) }
}

