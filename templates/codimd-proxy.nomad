{% from '_lib.hcl' import shutdown_delay, authproxy_group, task_logs, group_disk with context -%}

job "codimd-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 66


  ${- authproxy_group(
      'codimd',
      host='codimd.' + liquid_domain,
      upstream='codimd-app',
    ) }
}
