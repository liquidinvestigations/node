{% from '_lib.hcl' import shutdown_delay, group_disk, task_logs, continuous_reschedule, set_pg_password_template, set_pg_drop_template with context -%}
job "wikijs" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "wikijs" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "wikijs" {
      ${ task_logs() }
      driver = "docker"

      config {
        image = "${config.image('wikijs')}"
        port_map {
          wikijs = 3000
        }
        labels {
          liquid_task = "wikijs"
        }
        memory_hard_limit = 2000
      }

      env {
        DB_TYPE = "postgres"
        DB_PORT = ${config.port_wikijs_pg}
        DB_USER = "wikijs"
        DB_NAME = "wikijs"
        NODE_ENV = "development"
        # DB_HOST = "10.66.60.1"
        # DB_PASS = "test"
      }

      template {
        data = <<-EOF
          {{- with secret "liquid/wikijs/wikijs.postgres" -}}
              DB_PASS={{.Data.secret_key | toJSON }}
          {{- end }}
          DB_HOST = {{env "attr.unique.network.ip-address" }}
        EOF
        destination = "local/wikijs.env"
        env = true
      }

      resources {
        memory = 400
        cpu = 290
        network {
          mbits = 1
          port "wikijs" {}
        }
      }

      service {
        name = "liquid-wikijs"
        port = "wikijs"
        tags = [
          "fabio-:${config.port_wikijs} proto=tcp"
          # "traefik.enable=true",
          # "traefik.frontend.rule=Host:${'wikijs.' + liquid_domain}",
          # "fabio-:${config.port_wikijs} proto=tcp"
        ]
        check {
          initial_status = "critical"
          name = "http"
          path = "/healthz"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          type = "http"
          header {
            Host = ["wikijs.${liquid_domain}"]
          }
        }
      }
    }
  }
}