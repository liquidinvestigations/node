{% from '_lib.hcl' import set_pg_password_template, task_logs, group_disk with context -%}

job "hoover-workers" {
  datacenters = ["dc1"]
  type = "system"
  priority = 90

  group "snoop-workers" {
    ${ group_disk() }

    task "snoop-workers" {
      user = "root:root"
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
        args = ["/local/startup.sh"]
        entrypoint = ["/bin/bash", "-ex"]
        volumes = [
          ${hoover_snoop2_repo}
          "{% raw %}${meta.liquid_collections}{% endraw %}:/opt/hoover/collections",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/snoop/blobs:/opt/hoover/snoop/blobs",
        ]
        mounts = [
          {
            type = "tmpfs"
            target = "/tmp"
            readonly = false
            tmpfs_options {
              #size = 3221225472  # 3G
            }
          }
        ]
        labels {
          liquid_task = "snoop-workers"
        }
        memory_hard_limit = ${config.snoop_worker_hard_memory_limit}
      }

      resources {
        memory = ${config.snoop_worker_memory_limit}
        cpu = ${config.snoop_worker_cpu_limit}
      }

      template {
        data = <<-EOF
          #!/bin/bash
          set -ex
          # exec tail -f /dev/null
          if  [ -z "$SNOOP_TIKA_URL" ] \
                  || [ -z "$SNOOP_DB" ] \
                  || [ -z "$SNOOP_ES_URL" ] \
                  || [ -z "$SNOOP_AMQP_URL" ]; then
            echo "incomplete configuration!"
            sleep 5
            exit 1
          fi
          exec ./manage.py runworkers
          EOF
        env = false
        destination = "local/startup.sh"
      }

      env {
        SNOOP_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_es"
        SNOOP_TIKA_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_tika/"
        SNOOP_RABBITMQ_HTTP_URL = "{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_rabbit/"
        SNOOP_COLLECTIONS = ${ config.snoop_collections | tojson | tojson }

        SNOOP_MIN_WORKERS = "${config.snoop_min_workers_per_node}"
        SNOOP_MAX_WORKERS = "${config.snoop_max_workers_per_node}"
        SNOOP_CPU_MULTIPLIER = "${config.snoop_cpu_count_multiplier}"

        SNOOP_COLLECTION_ROOT = "/opt/hoover/collections"
        SYNC_FILES = "${sync}"
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

      #service {
      #  check {
      #    name = "check-workers-script"
      #    type = "script"
      #    command = "/bin/bash"
      #    args = ["-exc", "cd /opt/hoover/snoop; ./manage.py checkworkers"]
      #    interval = "${check_interval}"
      #    timeout = "${check_timeout}"
      #  }
      #}
    }
  }
}
