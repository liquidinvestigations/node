{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "drone" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  group "drone" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "drone" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }
      driver = "docker"
      config {
        image = "liquidinvestigations/drone:master"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/drone:/data",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "drone"
        }
        memory_hard_limit = 2048
      }

      env {
        DRONE_GITHUB_SERVER = "https://github.com"
        DRONE_SERVER_HOST = "jenkins.${liquid_domain}"
        DRONE_SERVER_PROTO = "${config.liquid_http_protocol}"
        DRONE_DATADOG_ENABLED = "false"
        DRONE_CLEANUP_DEADLINE_PENDING = "12h"
        DRONE_CLEANUP_DEADLINE_RUNNING = "2h"
        DRONE_CLEANUP_INTERVAL = "60m"
        DRONE_CLEANUP_DISABLED = "false"
      }

      template {
        data = <<-EOF

        {{- with secret "liquid/ci/drone.rpc.secret" }}
          DRONE_RPC_SECRET = "{{.Data.secret_key }}"
        {{- end }}

        {{- with secret "liquid/ci/drone.github" }}
          DRONE_GITHUB_CLIENT_ID = {{.Data.client_id | toJSON }}
          DRONE_GITHUB_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
          DRONE_USER_FILTER = {{.Data.user_filter | toJSON }}
        {{- end }}

        #DRONE_SECRET_PLUGIN_ENDPOINT = "http://{{ env "attr.unique.network.ip-address" }}:9997"
        #DRONE_SECRET_ENDPOINT = "http://{{ env "attr.unique.network.ip-address" }}:9997"
        {{- range service "drone-secret" }}
          DRONE_SECRET_PLUGIN_ENDPOINT = "http://{{.Address}}:{{.Port}}"
          DRONE_SECRET_ENDPOINT = "http://{{.Address}}:{{.Port}}"
        {{- end }}
        {{- with secret "liquid/ci/drone.secret.2" }}
          DRONE_SECRET_PLUGIN_SECRET = {{.Data.secret_key | toJSON }}
          DRONE_SECRET_SECRET = {{.Data.secret_key | toJSON }}
        {{- end }}
        DRONE_SECRET_PLUGIN_SKIP_VERIFY = "true"
        DRONE_SECRET_SKIP_VERIFY = "true"

        EOF
        destination = "local/drone.env"
        env = true
      }

      resources {
        memory = 350
        cpu = 150
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "drone"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:jenkins.${liquid_domain}",
          "fabio-/drone-server strip=/drone-server",
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
  }
}
