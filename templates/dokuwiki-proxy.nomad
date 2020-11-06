{% from '_lib.hcl' import authproxy_group, group_disk, task_logs with context -%}

job "dokuwiki-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65


  ${- authproxy_group(
      'dokuwiki',
      host='dokuwiki.' + liquid_domain,
      upstream='dokuwiki-php',
    ) }
}
