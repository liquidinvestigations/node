{% from '_lib.hcl' import authproxy_group_old with context -%}

job "hypothesis-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  ${- authproxy_group_old(
      'hypothesis',
      host='hypothesis.' + liquid_domain,
      upstream='hypothesis',
      user_header_template="acct:{}@" + liquid_domain,
    ) }
}
