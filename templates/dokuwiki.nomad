{% from '_lib.hcl' import authproxy_group, promtail_task with context -%}

job "dokuwiki" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  group "dokuwiki" {
    task "php" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config = {
        image = "bitnami/dokuwiki:0.20180422.201901061035"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/dokuwiki/data:/bitnami",
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
        cpu = 90
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

    ${ promtail_task() }
  }

  ${- authproxy_group(
      'dokuwiki',
      host='dokuwiki.' + liquid_domain,
      upstream='dokuwiki-php',
    ) }
}
