{%- macro continuous_reschedule() %}
  reschedule {
    unlimited = true
    attempts = 0
    delay = "5s"
  }
  restart {
    attempts = 3
    interval = "18s"
    delay = "4s"
    mode = "fail"
  }
{%- endmacro %}

{%- macro task_logs() %}
logs {
  max_files     = 5
  max_file_size = 1
}
{%- endmacro %}

{%- macro group_disk(size=50) %}
ephemeral_disk {
  size = ${size}
}
{%- endmacro %}

{%- macro authproxy_group(name, host, upstream) %}
  group "authproxy" {
    ${ continuous_reschedule() }

    task "web" {
      driver = "docker"
      config {
        image = "${config.image('liquidinvestigations/authproxy')}"
        volumes = [
          ${liquidinvestigations_authproxy_repo}
        ]
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
          LIQUID_PUBLIC_URL = ${config.liquid_http_protocol}://{{key "liquid_domain"}}
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
        memory = 150
        cpu = 150
      }
      service {
        name = "${name}-authproxy"
        port = "authproxy"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:${host}",
        ]
        check {
          name = "${name} authproxy http"
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
