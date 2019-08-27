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

  group "collections" {
    task "nginx" {
      driver = "docker"
      template {
        data = <<EOF
          server {
            listen 80 default_server;

            {{- if service "hoover-es" }}
              {{- with service "hoover-es" }}
                {{- with index . 0 }}
                  location ~ ^/_es/(.*) {
                    proxy_pass http://{{ .Address }}:{{ .Port }}/$1;
                  }
                {{- end }}
              {{- end }}
            {{- end }}

            {{- range services }}
              {{- if .Name | regexMatch "^snoop-" }}
                {{- with service .Name }}
                  {{- with index . 0 }}
                    location ~ ^/{{ .Name | regexReplaceAll "^(snoop-)" "" }}/(.*) {
                      proxy_pass http://{{ .Address }}:{{ .Port }}/$1;
                      proxy_set_header Host {{ .Name | regexReplaceAll "^(snoop-)" "" }}.snoop.{{ key "liquid_domain" }};
                    }
                  {{- end }}
                {{- end }}
              {{- end }}
            {{- end }}

          }

          {{- range services }}
            {{- if .Name | regexMatch "^snoop-" }}
              {{- with service .Name }}
                {{- with index . 0 }}
                  server {
                    listen 80;
                    server_name {{ .Name | regexReplaceAll "^(snoop-)" "" }}.snoop.{{ key "liquid_domain" }};
                    location / {
                      proxy_pass http://{{ .Address }}:{{ .Port }};
                      proxy_set_header Host $host;
                    }
                  }
                {{- end }}
              {{- end }}
            {{- end }}
          {{- end }}

          {{- if service "zipkin" }}
            {{- with service "zipkin" }}
              {{- with index . 0 }}
                server {
                  listen 80;
                  server_name zipkin.{{ key "liquid_domain" }};
                  location / {
                    proxy_pass http://{{ .Address }}:{{ .Port }};
                    proxy_set_header Host $host;
                  }
                }
              {{- end }}
            {{- end }}
          {{- end }}
          server_names_hash_bucket_size 128;
          EOF
        destination = "local/collections.conf"
      }
      config = {
        image = "nginx:1.17"
        port_map {
          nginx = 80
        }
        volumes = [
          "local/collections.conf:/etc/nginx/conf.d/collections.conf:ro",
        ]
        labels {
          liquid_task = "hoover-collections-nginx"
        }
      }
      resources {
        memory = 100
        network {
          mbits = 1
          port "nginx" {
            static = 8765
          }
        }
      }
      service {
        name = "hoover-collections"
        port = "nginx"
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
