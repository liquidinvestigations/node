{% from '_lib.hcl' import authproxy_group, group_disk, task_logs with context -%}

job "dokuwiki-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98


  ${- authproxy_group(
      'dokuwiki',
      host='dokuwiki.' + liquid_domain,
      upstream_port=config.port_dokuwiki,
      group='dokuwiki',
      redis_id=2
    ) }
}
