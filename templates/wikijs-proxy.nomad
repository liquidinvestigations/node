{% from '_lib.hcl' import authproxy_group, group_disk, task_logs with context -%}

job "wikijs-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98


  ${- authproxy_group(
      'wikijs',
      host='wikijs.' + liquid_domain,
      upstream_port=config.port_wikijs,
      group='wikijs',
      redis_id=5
    ) }
}