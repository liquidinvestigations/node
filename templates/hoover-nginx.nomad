{% from '_lib.hcl' import continuous_reschedule, task_logs, group_disk with context -%}

job "hoover-nginx" {
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
          sendfile on;
          sendfile_max_chunk 4m;
          aio threads;
          limit_rate 66m;

          upstream fabio {
            server {{env "attr.unique.network.ip-address"}}:9990;
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
            proxy_connect_timeout 159s;
            proxy_send_timeout   150;
            proxy_read_timeout   150;
            proxy_buffer_size    64k;
            proxy_buffers     16 32k;
            proxy_busy_buffers_size 64k;
            proxy_temp_file_write_size 64k;

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

            {% if config.hoover_maps_enabled %}
            location  ~ ^/api/map {
              rewrite ^/api/map(.*) /_maps_tileserver/$1 break;
              proxy_pass http://fabio;
            }
            location  ~ ^/api/geo {
              rewrite ^/api/geo(.*) /_maps_osmnames_sphinxsearch/$1 break;
              proxy_pass http://fabio;
            }
            {% endif %}

            location  ~ ^/(api/v0|api/v1|viewer|admin|accounts|static|swagger|redoc) {
              rewrite ^/(api/v0|api/v1|viewer|admin|accounts|static|swagger|redoc)(.*) /hoover-search/$1$2 break;
              proxy_pass http://fabio;
            }

            location  / {
              proxy_pass http://fabio/hoover-ui;
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
          limit = 5
          grace = "495s"
        }
      }
    }
  }

  {% if not config.hoover_ui_override_server %}
  group "hoover-ui" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "hoover-ui" {
      leader = true

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('hoover-ui')}"
        {% if config.hoover_ui_force_pull %}
          force_pull = true
        {% endif %}
        volumes = [
          ${hoover_ui_src_repo}
          ${hoover_ui_pages_repo}
          ${hoover_ui_styles_repo}
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover-ui/build:/opt/hoover/ui/build",
        ]
        port_map {
          http = 8000
        }
        labels {
          liquid_task = "hoover-ui"
        }
        args = ["sh", "/local/startup.sh"]
        memory_hard_limit = 3000
      }
      # used to auto-restart containers when running deploy, after you make a new commit
      env { __GIT_TAGS = "${hoover_ui_src_git}" }

      template {
        data = <<-EOF
        #!/bin/sh
        set -ex
        cp -v /local/.env.local .

        {% if config.liquid_debug %}
          exec npm run prod #dev
        {% else %}
          exec npm run prod
        {% endif %}
        EOF
        env = false
        destination = "local/startup.sh"
      }

      template {
        data = <<-EOF
          NEXT_PUBLIC_HOOVER_HYPOTHESIS_URL="${config.liquid_http_protocol}://hypothesis.${config.liquid_domain}/embed.js"
          API_URL = "http://{{env "attr.unique.network.ip-address"}}:9990/hoover-search"
        EOF
        env = true
        destination = "local/.env.local"
      }

      env {
        AGGREGATIONS_SPLIT = "${config.hoover_ui_agg_split}"
        MAX_SEARCH_RETRIES = "${config.hoover_ui_search_retry}"
      }

      {% if config.hoover_maps_enabled %}
      env {
        HOOVER_MAPS_ENABLED = "${config.hoover_maps_enabled}"
      }
      {% endif %}

      resources {
        memory = 900
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "hoover-ui"
        port = "http"
        tags = ["fabio-/hoover-ui strip=/hoover-ui"]
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
        check_restart {
          limit = 7
          grace = "295s"
        }
      }
    }
  }
  {% endif %}

  group "hoover-search-workers" {
    # this container also runs periodic tasks, so don't scale it up from here.
    count = 1
    ${ group_disk() }
    ${ continuous_reschedule() }
    task "hoover-search-workers" {
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

        memory_hard_limit = ${3 * config.hoover_web_memory_limit}
      }
      env { __GIT_TAGS = "${hoover_search_git}" }

      resources {
        memory = ${config.hoover_web_memory_limit}
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

        ./manage.py runperiodic &
        ./manage.py searchworker
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

          #HOOVER_HOSTNAME = "hoover.{{key "liquid_domain"}}"
          HOOVER_HOSTNAME = "*"
          HOOVER_TITLE = "Hoover"
          HOOVER_LIQUID_TITLE = "${config.liquid_title}"
          HOOVER_LIQUID_URL = "${config.liquid_core_url}"
          HOOVER_HYPOTHESIS_EMBED = "${config.liquid_http_protocol}://hypothesis.${config.liquid_domain}/embed.js"
          HOOVER_AUTHPROXY = "true"
          USE_X_FORWARDED_HOST = "true"
          LIQUID_CORE_LOGOUT_URL = "${config.liquid_core_url}/accounts/logout/?next=/"
          {%- if config.liquid_http_protocol == 'https' %}
            SECURE_PROXY_SSL_HEADER = "HTTP_X_FORWARDED_PROTO"
          {%- endif %}
          HOOVER_RATELIMIT_USER = ${config.hoover_ratelimit_user|tojson}
          HOOVER_ES_MAX_CONCURRENT_SHARD_REQUESTS = "${config.hoover_es_max_concurrent_shard_requests}"
          {{- range service "hoover-search-rabbitmq" }}
            SEARCH_AMQP_URL = "amqp://{{.Address}}:{{.Port}}"
          {{- end }}
        EOF
        destination = "local/hoover.env"
        env = true
      }

      service {
        check {
          name = "check-workers-script"
          type = "script"
          command = "/bin/sh"
          args = ["-c", "ps -o comm,args ax | grep '^celery .* worker'"]
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
