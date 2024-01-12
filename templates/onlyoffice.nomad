{% from '_lib.hcl' import shutdown_delay, group_disk, task_logs, continuous_reschedule with context -%}

job "onlyoffice" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "onlyoffice" {
    ${ group_disk() }
    ${ continuous_reschedule() }
    network {
      port "http" {
        to = 80
      }
    }

    task "onlyoffice" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      ${ shutdown_delay() }
      config {
        image = "onlyoffice/documentserver:latest"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud27/onlyoffice/document_data:/var/www/onlyoffice/Data",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud27/onlyoffice/document_log:/var/log/onlyoffice",
        ]
        ports = [
          "http",
        ]
        labels {
          liquid_task = "onlyoffice"
        }
        memory_hard_limit = 16384
      }

      env {
        JWT_SECRET = "secret"
      }

      resources {
        cpu = 500
        memory = 4096
      }

      service {
        name = "onlyoffice"
        port = "http"
        tags = ["fabio-:${config.port_onlyoffice} proto=tcp"]
        check {
          initial_status = "critical"
          name = "http"
          path = "/healthcheck"
          type = "http"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["onlyoffice.${liquid_domain}"]
          }
      }
    }
  }
}
}
