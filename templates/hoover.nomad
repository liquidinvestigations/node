{% from '_lib.hcl' import authproxy_group, continuous_reschedule, set_pg_password_template, promtail_task with context -%}

job "hoover" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  group "web" {
    task "search" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "${config.image('hoover-search')}"
        args = ["sh", "/local/startup.sh"]
        volumes = [
          ${hoover_search_repo}
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover-ui/build:/opt/hoover/ui/build",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "hoover-search"
        }
      }
      template {
        data = <<-EOF
        #!/bin/sh
        set -ex
        (
        set +x
        if [ -z "$HOOVER_DB" ]; then
          echo "database not ready"
          sleep 5
          exit 1
        fi
        )
        /wait
        ./manage.py migrate
        ./manage.py healthcheck
        exec waitress-serve --port 80 --threads=80 hoover.site.wsgi:application
        EOF
        env = false
        destination = "local/startup.sh"
      }
      env {
        HOOVER_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8765/_es"
      }
      template {
        data = <<-EOF
          {{- if keyExists "liquid_debug" }}
            DEBUG = {{key "liquid_debug" | toJSON }}
          {{- end }}
          {{- with secret "liquid/hoover/search.django" }}
            SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          {{- range service "hoover-pg" }}
            HOOVER_DB = "postgresql://search:
            {{- with secret "liquid/hoover/search.postgres" -}}
              {{.Data.secret_key }}
            {{- end -}}
            @{{.Address}}:{{.Port}}/search"
          {{- end }}

          HOOVER_HOSTNAME = "hoover.{{key "liquid_domain"}}"
          HOOVER_TITLE = "Hoover <a style="display:inline-block;margin-left:10px;" href="${config.liquid_core_url}">&#8594; ${config.liquid_title}</a>"
          HOOVER_HYPOTHESIS_EMBED = "https://hypothesis.${liquid_domain}/embed.js"
          HOOVER_AUTHPROXY = "true"
          USE_X_FORWARDED_HOST = "true"
          {%- if config.liquid_http_protocol == 'https' %}
            SECURE_PROXY_SSL_HEADER = "HTTP_X_FORWARDED_PROTO"
          {%- endif %}
          HOOVER_RATELIMIT_USER = ${config.hoover_ratelimit_user|tojson}
        EOF
        destination = "local/hoover.env"
        env = true
      }
      resources {
        memory = 300
        network {
          mbits = 1
          port "http" {}
        }
      }
      service {
        name = "hoover-search"
        port = "http"
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["hoover.${liquid_domain}"]
          }
        }
      }
    }

    ${ promtail_task() }
  }

  ${- authproxy_group(
      'hoover',
      host='hoover.' + liquid_domain,
      upstream='hoover-search',
    ) }
}
