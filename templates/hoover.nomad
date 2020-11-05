{% from '_lib.hcl' import snoop_extra_collection_volumes, authproxy_group, continuous_reschedule, set_pg_password_template, task_logs, group_disk with context -%}

job "hoover" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

  group "hoover-nginx" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "hoover-nginx" {
      ${ task_logs() }

      driver = "docker"

      config {
        image = "nginx:1.19"
        args = ["bash", "/local/startup.sh"]
        port_map {
          http = 8080
        }
        labels {
          liquid_task = "hoover-nginx"
        }
        memory_hard_limit = 1024
      }

      resources {
        memory = 128
        network {
          mbits = 1
          port "http" {}
        }
      }

      template {
        data = <<-EOF
        #!/bin/bash
        set -ex

        cat /local/nginx.conf
        nginx -c /local/nginx.conf
        EOF
        env = false
        destination = "local/startup.sh"
      }

      template {
        data = <<-EOF

        daemon off;
        error_log /dev/stdout info;
        worker_rlimit_nofile 8192;
        worker_processes 4;
        events {
          worker_connections 4096;
        }

        http {
          access_log  off;
          tcp_nopush   on;
          server_names_hash_bucket_size 128;

          upstream api {
            {{ range service "hoover-search" }}
              server "{{.Address}}:{{.Port}}";
            {{ end }}
          }

          upstream ui {
            {% if config.hoover_ui_override_server %}
              server "${config.hoover_ui_override_server}";
            {% else %}
              {{ range service "hoover-ui" }}
                server "{{.Address}}:{{.Port}}";
              {{ end }}
            {% endif %}
          }

          server {
            listen 8080 default_server;
            listen [::]:8080 default_server;

            {% if config.liquid_debug %}
              server_name _;
            {% else %}
              server_name "hoover.{{key "liquid_domain"}}";
            {% endif %}

            proxy_http_version  1.1;
            proxy_cache_bypass  $http_upgrade;

            proxy_set_header Upgrade           $http_upgrade;
            proxy_set_header Connection        "upgrade";
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host  $host;
            proxy_set_header X-Forwarded-Port  $server_port;
            proxy_pass_request_headers      on;

            location /_ping {
              return 200 "healthy\n";
            }

            location  ~ ^/(api|admin|accounts|static)/ {
              proxy_pass http://api;
            }

            location  / {
              proxy_pass http://ui;
            }
          }
        }
        EOF
        destination = "local/nginx.conf"
      }

      service {
        name = "hoover-nginx"
        port = "http"
        check {
          name = "ping"
          initial_status = "critical"
          type = "http"
          path = "/_ping"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["hoover.${liquid_domain}"]
          }
        }
        check_restart {
          limit = 3
          grace = "95s"
        }
      }
    }
  }

  ${- authproxy_group(
      'hoover',
      host='hoover.' + liquid_domain,
      upstream='hoover-nginx'
    ) }

  group "web" {
    count = ${config.hoover_web_count}
    ${ group_disk() }

    task "search" {
      ${ task_logs() }
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"

      config {
        image = "${config.image('hoover-search')}"
        args = ["bash", "/local/startup.sh"]
        volumes = [
          ${hoover_search_repo}
        ]
        port_map {
          http = 8080
        }
        labels {
          liquid_task = "hoover-search"
        }
        memory_hard_limit = ${3 * config.hoover_web_memory_limit}
      }

      resources {
        memory = ${config.hoover_web_memory_limit}
        network {
          mbits = 1
          port "http" {}
        }
      }

      template {
        data = <<-EOF
        #!/bin/bash
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
        ./manage.py synccollections "$SNOOP_COLLECTIONS"
        exec waitress-serve --port 8080 --threads=20 hoover.site.wsgi:application
        EOF
        env = false
        destination = "local/startup.sh"
      }

      env {
        HOOVER_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_es"
        SNOOP_COLLECTIONS = ${ config.snoop_collections | tojson | tojson }
        SNOOP_BASE_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/snoop"
      }

      template {
        data = <<-EOF
          {{- if keyExists "liquid_debug" }}
            DEBUG = {{key "liquid_debug" | toJSON }}
          {{- end }}
          {{- with secret "liquid/hoover/search.django" }}
            SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          {{- range service "search-pg" }}
            HOOVER_DB = "postgresql://search:
            {{- with secret "liquid/hoover/search.postgres" -}}
              {{.Data.secret_key }}
            {{- end -}}
            @{{.Address}}:{{.Port}}/search"
          {{- end }}

          HOOVER_HOSTNAME = "hoover.{{key "liquid_domain"}}"
          HOOVER_TITLE = "Hoover <a style="display:inline-block;margin-left:10px;" href="${config.liquid_core_url}">&#8594; ${config.liquid_title}</a>"
          HOOVER_HYPOTHESIS_EMBED = "${config.liquid_http_protocol}://hypothesis.${config.liquid_domain}/embed.js"
          HOOVER_AUTHPROXY = "true"
          USE_X_FORWARDED_HOST = "true"
          LIQUID_CORE_LOGOUT_URL = "${config.liquid_core_url}/accounts/logout/?next=/"
          {%- if config.liquid_http_protocol == 'https' %}
            SECURE_PROXY_SSL_HEADER = "HTTP_X_FORWARDED_PROTO"
          {%- endif %}
          HOOVER_RATELIMIT_USER = ${config.hoover_ratelimit_user|tojson}
        EOF
        destination = "local/hoover.env"
        env = true
      }

      service {
        name = "hoover-search"
        port = "http"
        check {
          name = "http_ping"
          initial_status = "critical"
          type = "http"
          path = "/api/v0/_ping"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["hoover.${liquid_domain}"]
          }
        }
        check_restart {
          limit = 3
          grace = "95s"
        }
      }
    }
  }

  group "snoop-celery-flower" {
    ${ continuous_reschedule() }
    ${ group_disk() }
    task "snoop-celery-flower" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('hoover-snoop2')}"
        args = ["bash", "/local/startup.sh"]
        volumes = [
          ${hoover_snoop2_repo}
        ]
        port_map {
          flower = 5555
        }
        labels {
          liquid_task = "snoop-worker"
        }
        memory_hard_limit = ${3 * config.hoover_web_memory_limit}
      }
      env {
        SNOOP_COLLECTION_ROOT = "/opt/hoover/collections"
        SYNC_FILES = "${sync}"
      }
      template {
        data = <<-EOF
          #!/bin/bash
          set -ex
          if  [ -z "$SNOOP_DB" ] \
                  || [ -z "$SNOOP_ES_URL" ] \
                  || [ -z "$SNOOP_AMQP_URL" ]; then
            echo "incomplete configuration!"
            sleep 5
            exit 1
          fi
          exec flower -A snoop.data -l INFO
          EOF
        env = false
        destination = "local/startup.sh"
      }
      env {
        SNOOP_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_es"
        SNOOP_TIKA_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_tika/"
        SNOOP_RABBITMQ_HTTP_URL = "{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_rabbit/"
        SNOOP_COLLECTIONS = ${ config.snoop_collections | tojson | tojson }
      }
      template {
        data = <<-EOF
        {{- if keyExists "liquid_debug" }}
          DEBUG = {{key "liquid_debug" | toJSON }}
        {{- end }}
        {{- range service "snoop-pg" }}
          SNOOP_DB = "postgresql://snoop:
          {{- with secret "liquid/hoover/snoop.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{.Address}}:{{.Port}}/snoop"
        {{- end }}
        {{- range service "hoover-rabbitmq" }}
          SNOOP_AMQP_URL = "amqp://{{.Address}}:{{.Port}}"
        {{- end }}
        {{ range service "zipkin" }}
          TRACING_URL = "http://{{.Address}}:{{.Port}}"
        {{- end }}
        EOF
        destination = "local/snoop.env"
        env = true
      }
      resources {
        memory = ${config.hoover_web_memory_limit}
        network {
          mbits = 1
          port "flower" {}
        }
      }
      service {
        name = "hoover-snoop-flower"
        port = "flower"
        tags = ["fabio-/flower strip=/flower"]
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

  {% if config.snoop_workers_enabled %}
  group "snoop-celery-beat" {
    ${ continuous_reschedule() }
    ${ group_disk() }
    task "snoop-celery-beat" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('hoover-snoop2')}"
        args = ["bash", "/local/startup.sh"]
        volumes = [
          ${hoover_snoop2_repo}
        ]
        memory_hard_limit = 400
      }
      template {
        data = <<-EOF
          #!/bin/bash
          set -ex
          if  [ -z "$SNOOP_DB" ] \
                  || [ -z "$SNOOP_ES_URL" ] \
                  || [ -z "$SNOOP_AMQP_URL" ]; then
            echo "incomplete configuration!"
            sleep 5
            exit 1
          fi
          exec celery -A snoop.data beat -l INFO --pidfile=
          EOF
        env = false
        destination = "local/startup.sh"
      }
      env {
        SNOOP_COLLECTION_ROOT = "/opt/hoover/collections"
        SYNC_FILES = "${sync}"
      }
      env {
        SNOOP_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_es"
        SNOOP_TIKA_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_tika/"
        SNOOP_RABBITMQ_HTTP_URL = "{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_rabbit/"
        SNOOP_COLLECTIONS = ${ config.snoop_collections | tojson | tojson }
      }
      template {
        data = <<-EOF
        {{- if keyExists "liquid_debug" }}
          DEBUG = {{key "liquid_debug" | toJSON }}
        {{- end }}
        {{- range service "snoop-pg" }}
          SNOOP_DB = "postgresql://snoop:
          {{- with secret "liquid/hoover/snoop.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{.Address}}:{{.Port}}/snoop"
        {{- end }}
        {{- range service "hoover-rabbitmq" }}
          SNOOP_AMQP_URL = "amqp://{{.Address}}:{{.Port}}"
        {{- end }}
        {{ range service "zipkin" }}
          TRACING_URL = "http://{{.Address}}:{{.Port}}"
        {{- end }}
        EOF
        destination = "local/snoop.env"
        env = true
      }
      resources {
        memory = 100
      }
    }
  } // snoop-celery-beat
  {% endif %}

  group "snoop-web" {
    count = ${config.hoover_web_count}
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "snoop" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      constraint {
        attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "${config.image('hoover-snoop2')}"
        args = ["bash", "/local/startup.sh"]
        volumes = [
          ${hoover_snoop2_repo}
          ${snoop_extra_collection_volumes()}
          "{% raw %}${meta.liquid_volumes}{% endraw %}/snoop/blobs:/opt/hoover/snoop/blobs",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "snoop-api"
        }
        memory_hard_limit = ${3 * config.hoover_web_memory_limit}
      }
      env {
        SNOOP_COLLECTION_ROOT = "/opt/hoover/collections"
        SNOOP_URL_PREFIX = "snoop/"
      }
      template {
        data = <<-EOF
          #!/bin/bash
          set -ex
          if [ -z "$SNOOP_ES_URL" ] || [ -z "$SNOOP_DB" ]; then
            echo "incomplete configuration!"
            sleep 5
            exit 1
          fi
          date
          ./manage.py migrate --noinput
          ./manage.py migratecollections
          ./manage.py healthcheck
          date
          if [[ "$DEBUG" == "true" ]]; then
            exec ./manage.py runserver 0.0.0.0:80
          else
            exec /runserver
          fi
          EOF
        env = false
        destination = "local/startup.sh"
      }
      env {
        SNOOP_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_es"
        SNOOP_TIKA_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_tika/"
        SNOOP_RABBITMQ_HTTP_URL = "{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_rabbit/"
        SNOOP_COLLECTIONS = ${ config.snoop_collections | tojson | tojson }
      }
      template {
        data = <<-EOF
        {{- if keyExists "liquid_debug" }}
          DEBUG = {{ key "liquid_debug" | toJSON }}
        {{- end }}
        {{- with secret "liquid/hoover/snoop.django" }}
          SECRET_KEY = {{.Data.secret_key | toJSON }}
        {{- end }}
        {{- range service "snoop-pg" }}
          SNOOP_DB = "postgresql://snoop:
          {{- with secret "liquid/hoover/snoop.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{.Address}}:{{.Port}}/snoop"
        {{- end }}

        {{- range service "hoover-rabbitmq" }}
          SNOOP_AMQP_URL = "amqp://{{.Address}}:{{.Port}}"
        {{- end }}
        {{- range service "zipkin" }}
          TRACING_URL = "http://{{.Address}}:{{.Port}}"
        {{- end }}
        EOF
        destination = "local/snoop.env"
        env = true
      }
      resources {
        memory = ${config.hoover_web_memory_limit}
        cpu = 200
        network {
          mbits = 1
          port "http" {}
        }
      }
      service {
        name = "hoover-snoop"
        port = "http"
        tags = ["fabio-/snoop"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/snoop/_health"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["snoop.${liquid_domain}"]
          }
        }
      }
    }
  }
}
