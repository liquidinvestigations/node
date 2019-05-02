{%- macro migration_reschedule() %}
  reschedule {
    attempts = 10
    interval = "5m"
    delay = "5s"
    delay_function = "exponential"
    max_delay = "30s"
  }
{%- endmacro %}

{%- macro authproxy(name, host, upstream) %}
  group "authproxy" {
    task "web" {
      driver = "docker"
      config {
        image = "liquidinvestigations/authproxy"
        labels {
          liquid_task = "${name}-authproxy"
        }
        port_map {
          authproxy = 5000
        }
      }
      template {
        data = <<EOF
          {{- range service "${upstream}" }}
            UPSTREAM_APP_URL = http://{{.Address}}:{{.Port}}
          {{- end }}
          DEBUG = {{key "liquid_debug"}}
          USER_HEADER_TEMPLATE = {}
          {{- range service "core" }}
            LIQUID_INTERNAL_URL = http://{{.Address}}:{{.Port}}
          {{- end }}
          LIQUID_PUBLIC_URL = http://{{key "liquid_domain"}}
          {{- with secret "liquid/${name}/auth.django" }}
            SECRET_KEY = {{.Data.secret_key}}
          {{- end }}
          {{- with secret "liquid/${name}/auth.oauth2" }}
            LIQUID_CLIENT_ID = {{.Data.client_id}}
            LIQUID_CLIENT_SECRET = {{.Data.client_secret}}
          {{- end }}
        EOF
        destination = "local/docker.env"
        env = true
      }
      resources {
        network {
          port "authproxy" {}
        }
      }
      service {
        name = "${name}"
        port = "authproxy"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:${host}",
        ]
        check {
          name = "${name}"
          initial_status = "critical"
          type = "http"
          path = "/__auth/logout"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
{%- endmacro %}
