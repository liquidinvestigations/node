{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule, shutdown_delay -%}

job "drone-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  group "drone-secret" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "drone-secret" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "drone/vault:1.2"
        port_map {
          http = 3000
        }
        labels {
          liquid_task = "drone-secret"
        }
        memory_hard_limit = 1024
      }

      env {
        DRONE_DEBUG = "true"
        VAULT_ADDR = "${config.vault_url}"
        VAULT_TOKEN = "${config.vault_token}"
        VAULT_SKIP_VERIFY = "true"
        VAULT_MAX_RETRIES = "15"
      }

      template {
        data = <<-EOF
          {{- with secret "liquid/ci/drone.secret.2" }}
            DRONE_SECRET = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/drone.env"
        env = true
      }

      resources {
        memory = 150
        cpu = 150
        network {
          mbits = 1
          port "http" { static = 10003 }
        }
      }

      service {
        name = "drone-secret"
        port = "http"
        tags = ["fabio-:${config.port_drone_ci} proto=tcp"]
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
        check_restart {
          limit = 5
          grace = "290s"
        }
      }
    }
  }
}
