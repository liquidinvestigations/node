{% from '_lib.hcl' import authproxy_group with context -%}

job "nextcloud-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  ${- authproxy_group(
      'nextcloud',
      host='nextcloud.' + liquid_domain,
      upstream='nextcloud-app',
    ) }
}
