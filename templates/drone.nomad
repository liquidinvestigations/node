{% from '_lib.hcl' import group_disk, task_logs, promtail_task -%}

job "drone" {
  datacenters = ["dc1"]
  type = "service"
  priority = 90

  group "drone-secret" {
    ${ group_disk() }
    task "drone-secret" {
      ${ task_logs() }
      driver = "docker"
      config {
        image = "drone/vault"
        port_map {
          http = 3000
        }
        labels {
          liquid_task = "drone-secret"
        }
      }
      env {
        VAULT_ADDR = "${config.vault_url}"
        VAULT_TOKEN = "${config.vault_token}"
        VAULT_SKIP_VERIFY = "true"
        VAULT_MAX_RETRIES = "5"
      }
      template {
        data = <<-EOF
          {{- with secret "liquid/ci/drone.secret" }}
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
          port "http" {
            static = 9996
          }
        }
      }
      service {
        name = "drone-secret"
        port = "http"
        check {
          name = "tcp on http port :)"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    ${ promtail_task() }
  }


  group "drone" {
    ${ group_disk() }
    task "drone" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }
      driver = "docker"
      config {
        image = "drone/drone:1.4.0"
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/drone:/data",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "drone"
        }
      }
      env {
        DRONE_LOGS_DEBUG = "true"
        DRONE_GITHUB_SERVER = "https://github.com"
        DRONE_SERVER_HOST = "jenkins.${liquid_domain}"
        DRONE_SERVER_PROTO = "${config.liquid_http_protocol}"
        DRONE_RUNNER_CAPACITY = "${config.ci_runner_capacity}"
      }
      template {
        data = <<-EOF
          {{- range service "vmck" }}
            DRONE_RUNNER_ENVIRON = "VMCK_IP:{{.Address}},VMCK_PORT:{{.Port}}${config.ci_docker_registry_env}"
          {{- end }}
          {{- range service "drone-secret" }}
            DRONE_SECRET_ENDPOINT = "http://{{.Address}}:{{.Port}}"
          {{- end }}
          {{- with secret "liquid/ci/drone.secret" }}
            DRONE_SECRET_SECRET = {{.Data.secret_key | toJSON }}
          {{- end }}
          DRONE_SECRET_SKIP_VERIFY = "true"
          {{- with secret "liquid/ci/drone.github" }}
            DRONE_GITHUB_CLIENT_ID = {{.Data.client_id | toJSON }}
            DRONE_GITHUB_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
            DRONE_USER_FILTER = {{.Data.user_filter | toJSON }}
          {{- end }}
        EOF
        destination = "local/drone.env"
        env = true
      }
      resources {
        memory = 250
        cpu = 150
        network {
          mbits = 1
          port "http" {
            static = 9997
          }
        }
      }
      service {
        name = "drone"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:jenkins.${liquid_domain}",
        ]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    ${ promtail_task() }
  }
}
