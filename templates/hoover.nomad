{% from '_lib.hcl' import authproxy_group, continuous_reschedule, set_pg_password_template with context -%}

job "hoover" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  group "web" {
    task "search" {
      driver = "docker"
      config {
        image = "${config.image('hoover-search')}"
        args = ["sh", "/local/startup.sh"]
        volumes = [
          ${hoover_search_repo}
          "${liquid_volumes}/hoover-ui/build:/opt/hoover/ui/build",
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
        exec ./runserver
        EOF
        env = false
        destination = "local/startup.sh"
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
          {{- range service "hoover-es" }}
            HOOVER_ES_URL = "http://{{.Address}}:{{.Port}}"
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
  }

  ${- authproxy_group(
      'hoover',
      host='hoover.' + liquid_domain,
      upstream='hoover-search',
    ) }

  group "collections-lb" {
    task "fabio" {
      driver = "docker"
      config {
        image = "fabiolb/fabio:1.5.11-go1.11.5"
        volumes = [
          "local/fabio.properties:/etc/fabio/fabio.properties"
        ]
        port_map {
          ui = 9991
          lb = 9990
        }
      }
      template {
        destination = "local/fabio.properties"
        data = <<-EOH
          registry.backend = consul
          registry.consul.addr = ${consul_url}
          registry.consul.checksRequired = all
          registry.consul.tagprefix = snoop-
          ui.addr = :9991
          ui.color = blue
          proxy.addr = :9990
          EOH
      }

      resources {
        cpu = 100
        memory = 100
        network {
          mbits = 1
          port "lb" {
            static = 8765
          }
          port "ui" {
            static = 8764
          }
        }
      }
    }
  }
}
