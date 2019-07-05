{% from '_lib.hcl' import authproxy_group, continuous_reschedule with context -%}

job "hoover" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  group "index" {
    task "es" {
      driver = "docker"
      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch-oss:6.2.4"
        args = ["/bin/sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data && echo chown done && /usr/local/bin/docker-entrypoint.sh"]
        volumes = [
          "${liquid_volumes}/hoover/es/data:/usr/share/elasticsearch/data",
        ]
        port_map {
          es = 9200
        }
        labels {
          liquid_task = "hoover-es"
        }
      }
      env {
        cluster.name = "hoover"
        ES_JAVA_OPTS = "-Xms1024m -Xmx1024m"
      }
      resources {
        memory = 2000
        network {
          port "es" {}
        }
      }
      service {
        name = "hoover-es"
        port = "es"
        check {
          name = "hoover-es alive on http"
          initial_status = "critical"
          type = "http"
          path = "/_cluster/health"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "db" {
    ${ continuous_reschedule() }

    task "pg" {
      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "${liquid_volumes}/hoover/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "hoover-pg"
        }
        port_map {
          pg = 5432
        }
      }
      env {
        POSTGRES_USER = "search"
        POSTGRES_DATABASE = "search"
      }
      resources {
        memory = 350
        network {
          port "pg" {}
        }
      }
      service {
        name = "hoover-pg"
        port = "pg"
        check {
          name = "hoover-pg alive on tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "tika" {
    task "tika" {
      driver = "docker"
      config {
        image = "logicalspark/docker-tikaserver"
        port_map {
          tika = 9998
        }
        labels {
          liquid_task = "tika"
        }
      }
      resources {
        memory = 800
        cpu = 200
        network {
          port "tika" {}
        }
      }
      service {
        name = "tika"
        port = "tika"
        check {
          name = "tika alive on http"
          initial_status = "critical"
          type = "http"
          path = "/version"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "web" {
    task "search" {
      driver = "docker"
      config {
        image = "${config.image('liquidinvestigations/hoover-search')}"
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
        data = <<EOF
          {{- if keyExists "liquid_debug" }}
            DEBUG = {{key "liquid_debug"}}
          {{- end }}
          {{- with secret "liquid/hoover/search.django" }}
            SECRET_KEY = {{.Data.secret_key}}
          {{- end }}
          {{- range service "hoover-pg" }}
            HOOVER_DB = postgresql://search:search@{{.Address}}:{{.Port}}/search
          {{- end }}
          {{- range service "hoover-es" }}
            HOOVER_ES_URL = http://{{.Address}}:{{.Port}}
          {{- end }}
          HOOVER_HOSTNAME = hoover.{{key "liquid_domain"}}
          HOOVER_TITLE = "Hoover <a style="display:inline-block;margin-left:10px;" href="${config.liquid_core_url}">&#8594; ${config.liquid_title}</a>"
          HOOVER_AUTHPROXY = true
          USE_X_FORWARDED_HOST = true
          {%- if config.liquid_http_protocol == 'https' %}
            SECURE_PROXY_SSL_HEADER = HTTP_X_FORWARDED_PROTO
          {%- endif %}
        EOF
        destination = "local/hoover.env"
        env = true
      }
      resources {
        memory = 300
        network {
          port "http" {}
        }
      }
      service {
        name = "hoover-search"
        port = "http"
        check {
          name = "hoover /_ping succeeds"
          initial_status = "critical"
          type = "http"
          path = "/_ping"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["hoover.${liquid_domain}"]
          }
        }
        check {
          name = "hoover alive on http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["hoover.${liquid_domain}"]
          }
        }
        check {
          name = "hoover healthcheck script"
          initial_status = "warning"
          type = "script"
          command = "python"
          args = ["manage.py", "healthcheck"]
          interval = "${check_interval}"
          timeout = "${check_timeout}"
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

            {{- if service "tika" }}
              {{- with service "tika" }}
                {{- with index . 0 }}
                  location ~ ^/(.*) {
                    proxy_pass http://{{ .Address }}:{{ .Port }}/$1;
                    proxy_set_header Host tika.{{ key "liquid_domain" }};
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
        image = "nginx"
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
          port "nginx" {
            static = 8765
          }
        }
      }
      service {
        name = "hoover-collections"
        port = "nginx"
        check {
          name = "hoover-collections nginx on :8765 forwards elasticsearch"
          initial_status = "critical"
          type = "http"
          path = "/_es/_cluster/health/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
