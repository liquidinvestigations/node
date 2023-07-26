{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}
{% from 'hoover.nomad' import snoop_dependency_envs with context %}

job "hoover-migrate" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 99

  group "hoover-search-migrate" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "hoover-search-migrate" {
      leader = true

      constraint {
        attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"

      config {
        image = "${config.image('hoover-search')}"
        entrypoint = ["/bin/bash", "-ex"]
        args = ["/local/startup.sh"]
        volumes = [
          ${hoover_search_repo}
          "{% raw %}${meta.liquid_collections}{% endraw %}:/opt/hoover/collections",
        ]
        labels {
          liquid_task = "hoover-search-migrate"
        }
        memory_hard_limit = ${2000 + 4 * config.hoover_web_memory_limit}
      }

      resources {
        memory = ${config.hoover_web_memory_limit}
        cpu = 200
      }

      env {
        __GIT_TAGS = "${hoover_search_git}"
        HOOVER_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/_es"
        SNOOP_COLLECTIONS = ${ config.snoop_collections | tojson | tojson }
        SNOOP_BASE_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/snoop"
        DEBUG_WAIT_PER_COLLECTION = ${config.hoover_search_debug_delay}

        GUNICORN_WORKER_CLASS = "gthread"
        GUNICORN_WORKERS = "4"
        GUNICORN_THREADS = "8"
        GUNICORN_MAX_REQUESTS = "1000"
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
          SEARCH_AMQP_URL = "amqp://{{env "attr.unique.network.ip-address" }}:${config.port_search_rabbitmq}"

        EOF
        destination = "local/hoover.env"
        env = true
      }

      template {
        data = <<-EOF
          #!/bin/bash
          set -ex
          date
          ./manage.py checkesdiskusage
          ./manage.py migrate
          ./manage.py healthcheck
          ./manage.py synccollections "$SNOOP_COLLECTIONS"
          date

          EOF
        env = false
        destination = "local/startup.sh"
      }

    }
  }

  group "hoover-snoop2-migrate" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "hoover-snoop2-migrate" {
      leader = true

      ${ task_logs() }

      user = "root:root"
      driver = "docker"
      config {
        image = "${config.image('hoover-snoop2')}"
        cap_add = ["mknod", "sys_admin"]
        devices = [{host_path = "/dev/fuse", container_path = "/dev/fuse"}]
        security_opt = ["apparmor=unconfined"]
        entrypoint = ["/bin/bash", "-ex"]
        args = ["/local/startup.sh"]
        volumes = [
          ${hoover_snoop2_repo}
        ]
        labels {
          liquid_task = "snoop-migrate"
        }
        memory_hard_limit = ${2000 + 4 * config.hoover_web_memory_limit}
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

          EOF
        env = false
        destination = "local/startup.sh"
      }

      ${ snoop_dependency_envs() }

      resources {
        memory = ${config.hoover_web_memory_limit}
        cpu = 200
      }
    }
  }

}
