{% from '_lib.hcl' import authproxy_group with context -%}

job "dokuwiki" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  group "dokuwiki" {
    task "php" {
      driver = "docker"
      config = {
        image = "bitnami/dokuwiki:0"
        volumes = [
          "${liquid_volumes}/dokuwiki/data:/bitnami",
        ]
        labels {
          liquid_task = "dokuwiki"
        }
        port_map {
          php = 80
        }
      }
      resources {
        memory = 500
        cpu = 200
        network {
          mbits = 1
          port "php" {}
        }
      }
      service {
        name = "dokuwiki-php"
        port = "php"
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["dokuwiki.${liquid_domain}"]
          }
        }
      }
    }
  }

  ${- authproxy_group(
      'dokuwiki',
      host='dokuwiki.' + liquid_domain,
      upstream='dokuwiki-php',
    ) }
}
