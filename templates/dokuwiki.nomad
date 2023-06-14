{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule with context -%}

job "dokuwiki" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "dokuwiki" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "php" {
      ${ task_logs() }
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "${config.image('liquid-dokuwiki')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/dokuwiki/data:/bitnami",
        ]
        labels {
          liquid_task = "dokuwiki"
        }
        port_map {
          php = 80
        }
        memory_hard_limit = 1500
      }

      env {
        LIQUID_CORE_URL = ${config.liquid_core_url|tojson}
        LIQUID_CORE_LOGOUT_URL = "${config.liquid_core_url}/accounts/logout/?next=/"
        LIQUID_TITLE = ${config.liquid_title|tojson}
        LIQUID_DOMAIN = ${config.liquid_domain|tojson}
        LIQUID_HTTP_PROTOCOL = ${config.liquid_http_protocol|tojson}
      }

      resources {
        memory = 400
        cpu = 290
        network {
          mbits = 1
          port "php" {}
        }
      }

      service {
        name = "dokuwiki-php"
        port = "php"
        tags = ["fabio-:${config.port_dokuwiki} proto=tcp"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/doku.php"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["dokuwiki.${liquid_domain}"]
          }
        }
      }
    }
  }
}
