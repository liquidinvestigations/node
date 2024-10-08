{% from '_lib.hcl' import continuous_reschedule, task_logs, group_disk with context -%}

job "hoover-nginx" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

  group "hoover-nginx" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "hoover-nginx" {
      ${ task_logs() }

      driver = "docker"

      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = -99
      }

      config {
        image = "nginx:1.19"
        args = ["bash", "/local/startup.sh"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover/ui-build-v0.21/out:/hoover-ui",
        ]
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

        {% if config.liquid_debug %}
          error_log /dev/stderr debug;
        {% else %}
          error_log /dev/stderr info;
        {% endif %}

        worker_rlimit_nofile 8192;
        worker_processes 4;
        events {
          worker_connections 4096;
        }

        http {
          {% if config.liquid_debug %}
            access_log  /dev/stdout;
          {% else %}
            access_log  off;
          {% endif %}
          default_type  application/octet-stream;
          include       /etc/nginx/mime.types;

          tcp_nopush   on;
          server_names_hash_bucket_size 128;
          sendfile on;
          sendfile_max_chunk 4m;
          aio threads;
          limit_rate 66m;

          upstream fabio {
            server {{env "attr.unique.network.ip-address"}}:${config.port_lb};
          }

          server {
            listen 8080 default_server;
            listen [::]:8080 default_server;
            root /hoover-ui;

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
            proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
            proxy_set_header X-Forwarded-Host  $host;
            proxy_set_header X-Forwarded-Port  $server_port;
            proxy_pass_request_headers      on;

            client_max_body_size 5M;

            location /_ping {
              return 200 "healthy\n";
            }

            {% if config.hoover_maps_enabled %}
            location  ~ ^/api/map {
              rewrite ^/api/map(.*) /_maps_tileserver$1 break;
              proxy_pass http://fabio;
            }
            location  ~ ^/api/geo {
              rewrite ^/api/geo(.*) /_maps_osmnames_sphinxsearch$1 break;
              proxy_pass http://fabio;
            }
            {% endif %}

            location  ^~ /libre_translate/static {
              rewrite ^/libre_translate/static(.*) /libre_translate/libre_translate/static$1 break;
              proxy_pass http://fabio;
            }
            location  ~ ^/libre_translate {
              rewrite ^/libre_translate(.*) /libre_translate$1 break;
              proxy_pass http://fabio;
            }

            location  ~ ^/(api/v0|api/v1|viewer|admin|accounts|static|swagger|redoc) {
              rewrite ^/(api/v0|api/v1|viewer|admin|accounts|static|swagger|redoc)(.*) /hoover-search/$1$2 break;
              proxy_pass http://fabio;
            }

            # include /hoover-ui/nginx-routes.conf;
            location / {
              try_files $uri $uri/ /index.html;
            }
          }
        }
        EOF
        destination = "local/nginx.conf"
      }

      service {
        name = "hoover-nginx"
        port = "http"
        tags = ["fabio-:${config.port_hoover} proto=tcp"]
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
          grace = "995s"
        }
      }
    }
  }

  group "hoover-search-workers" {
    # this container also runs periodic tasks, so don't scale it up from here.
    count = 1
    spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

    ${ group_disk() }
    ${ continuous_reschedule() }
    task "hoover-search-workers" {
      ${ task_logs() }

      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = -99
      }

      driver = "docker"

      config {
        image = "${config.image('hoover-search')}"
        args = ["bash", "/local/startup.sh"]

        volumes = [
          ${hoover_search_repo}
        ]

        memory_hard_limit = ${2000 + 3 * config.hoover_web_memory_limit}
      }

      resources {
        memory = ${int(config.hoover_web_memory_limit/2)}
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
        ./manage.py searchworker search
        EOF
        env = false
        destination = "local/startup.sh"
      }

      env {
        __GIT_TAGS = "${hoover_search_git}"

        HOOVER_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/_es"
        SNOOP_COLLECTIONS = ${ config.snoop_collections | tojson | tojson }
        SNOOP_BASE_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/snoop"
        DEBUG_WAIT_PER_COLLECTION = ${config.hoover_search_debug_delay}
        HOOVER_NEXTCLOUD_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_nextcloud28}"
      }

      template {
        data = <<-EOF
          {{- if keyExists "liquid_debug" }}
            DEBUG = {{key "liquid_debug" | toJSON }}
          {{- end }}
          {{- with secret "liquid/hoover/search.django" }}
            SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          HOOVER_DB = "postgresql://search:
          {{- with secret "liquid/hoover/search.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{env "attr.unique.network.ip-address" }}:${config.port_search_pg}/search"

          #HOOVER_HOSTNAME = "hoover.{{key "liquid_domain"}}"
          HOOVER_HOSTNAME = "*"
          HOOVER_TITLE = "Hoover"
          HOOVER_LIQUID_TITLE = "${config.liquid_title}"
          HOOVER_LIQUID_URL = "${config.liquid_core_url}"
          HOOVER_AUTHPROXY = "true"
          USE_X_FORWARDED_HOST = "true"
          LIQUID_CORE_LOGOUT_URL = "${config.liquid_core_url}/accounts/logout/?next=/"
          {%- if config.liquid_http_protocol == 'https' %}
            SECURE_PROXY_SSL_HEADER = "HTTP_X_FORWARDED_PROTO"
          {%- endif %}
          HOOVER_RATELIMIT_USER = ${config.hoover_ratelimit_user|tojson}
          HOOVER_ES_MAX_CONCURRENT_SHARD_REQUESTS = "${config.hoover_es_max_concurrent_shard_requests}"
          SEARCH_AMQP_URL = "amqp://{{ env "attr.unique.network.ip-address" }}:${config.port_search_rabbitmq}"

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

  group "hoover-batch-workers" {
    # this container also runs periodic tasks, so don't scale it up from here.
    count = 1
    spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

    ${ group_disk() }
    ${ continuous_reschedule() }
    task "hoover-batch-workers" {
      ${ task_logs() }

      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = -99
      }

      driver = "docker"

      config {
        image = "${config.image('hoover-search')}"
        args = ["bash", "/local/startup.sh"]

        volumes = [
          ${hoover_search_repo}
        ]

        memory_hard_limit = ${2000 + 3 * config.hoover_web_memory_limit}
      }

      resources {
        memory = ${int(config.hoover_web_memory_limit/2)}
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

        ./manage.py searchworker batch
        EOF
        env = false
        destination = "local/startup.sh"
      }

      env {
        __GIT_TAGS = "${hoover_search_git}"
        HOOVER_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/_es"
        SNOOP_COLLECTIONS = ${ config.snoop_collections | tojson | tojson }
        SNOOP_BASE_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/snoop"
        DEBUG_WAIT_PER_COLLECTION = ${config.hoover_search_debug_delay}
        HOOVER_NEXTCLOUD_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_nextcloud28}"
      }

      template {
        data = <<-EOF
          {{- if keyExists "liquid_debug" }}
            DEBUG = {{key "liquid_debug" | toJSON }}
          {{- end }}
          {{- with secret "liquid/hoover/search.django" }}
            SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          HOOVER_DB = "postgresql://search:
          {{- with secret "liquid/hoover/search.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{env "attr.unique.network.ip-address" }}:${config.port_search_pg}/search"

          #HOOVER_HOSTNAME = "hoover.{{key "liquid_domain"}}"
          HOOVER_HOSTNAME = "*"
          HOOVER_TITLE = "Hoover"
          HOOVER_LIQUID_TITLE = "${config.liquid_title}"
          HOOVER_LIQUID_URL = "${config.liquid_core_url}"
          HOOVER_AUTHPROXY = "true"
          USE_X_FORWARDED_HOST = "true"
          LIQUID_CORE_LOGOUT_URL = "${config.liquid_core_url}/accounts/logout/?next=/"
          {%- if config.liquid_http_protocol == 'https' %}
            SECURE_PROXY_SSL_HEADER = "HTTP_X_FORWARDED_PROTO"
          {%- endif %}
          HOOVER_RATELIMIT_USER = ${config.hoover_ratelimit_user|tojson}
          HOOVER_ES_MAX_CONCURRENT_SHARD_REQUESTS = "${config.hoover_es_max_concurrent_shard_requests}"
          SEARCH_AMQP_URL = "amqp://{{ env "attr.unique.network.ip-address" }}:${config.port_search_rabbitmq}"
        EOF
        destination = "local/hoover.env"
        env = true
      }

      service {
        check {
          name = "check-batch-workers"
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
