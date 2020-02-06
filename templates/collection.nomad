{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule, set_pg_password_template, promtail_task, airflow_env_template, dask_env_template with context -%}

job "collection-${name}" {
  datacenters = ["dc1"]
  type = "service"
  priority = 55

  group "workers" {
    ${ group_disk() }

    count = ${workers}

    task "snoop" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      constraint {
        attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('hoover-snoop2')}"
        force_pull = "true"

        args = ["sh", "/local/startup.sh"]
        volumes = [
          ${hoover_snoop2_repo}
          "{% raw %}${meta.liquid_collections}{% endraw %}/${name}:/opt/hoover/collection",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/collections/${name}/blobs:/opt/hoover/snoop/blobs",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/collections/${name}/dask-worker-{% raw %}${NOMAD_ALLOC_INDEX}{% endraw %}:/dask-worker",
        ]
        port_map {
          flower = 5555
        }
        labels {
          liquid_task = "snoop-${name}-worker"
        }
      }

      env {
        SNOOP_COLLECTION_ROOT = "/opt/hoover/collection"
        SNOOP_TASK_PREFIX = "${name}"
        SNOOP_ES_INDEX = "${name}"
        SYNC_FILES = "${sync}"
      }

      ${ airflow_env_template() }

      ${ dask_env_template() }

      env {
        HOST = "{% raw %}${attr.unique.network.ip-address}{% endraw %}"
        WORKER_PORT = "{% raw %}${NOMAD_HOST_PORT_worker}{% endraw %}"
        DASH_PORT = "{% raw %}${NOMAD_HOST_PORT_dashboard}{% endraw %}"
      }

      template {
        data = <<-EOF
        #!/bin/bash
        set -ex
        if  [ -z "$SNOOP_TIKA_URL" ] \
                || [ -z "$SNOOP_DB" ] \
                || [ -z "$SNOOP_DASK_SCHEDULER_URL" ] \
                || [ -z "$SNOOP_ES_URL" ] \
                || [ -z "$SNOOP_AMQP_URL" ]; then
          echo "incomplete configuration!"
          sleep 5
          exit 1
        fi

        dask-worker \
                --listen-address "tcp://0.0.0.0:$WORKER_PORT" \
                --contact-address "tcp://$HOST:$WORKER_PORT" \
                --dashboard-address "0.0.0.0:$DASH_PORT" \
                --no-nanny \
                --nthreads 1 \
                --nprocs 1 \
                --memory-limit "${worker_memory_limit}M" \
                --local-directory "/dask-worker" \
                --preload "/opt/hoover/snoop/django_setup.py" \
                --dashboard-prefix "/_dask/${name}/worker" \
                --death-timeout "40" \
                "$SNOOP_DASK_SCHEDULER_URL"
        EOF
        env = false
        destination = "local/startup.sh"
      }
      env {
        SNOOP_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8765/_es"
        SNOOP_STATS_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8765/_es"
        SNOOP_STATS_ES_PREFIX = ".hoover-snoopstats-"
        SNOOP_TIKA_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8765/_tika/"
        SNOOP_WORKER_COUNT = "${worker_process_count}"
      }
      template {
        data = <<-EOF
        {{- if keyExists "liquid_debug" }}
          DEBUG = {{key "liquid_debug" | toJSON }}
        {{- end }}
        {{- range service "snoop-${name}-pg" }}
          SNOOP_DB = "postgresql://snoop:
          {{- with secret "liquid/collections/${name}/snoop.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{.Address}}:{{.Port}}/snoop"
        {{- end }}
        {{- range service "snoop-${name}-rabbitmq" }}
          SNOOP_AMQP_URL = "amqp://{{.Address}}:{{.Port}}"
        {{- end }}
        {{ range service "zipkin" }}
          TRACING_URL = "http://{{.Address}}:{{.Port}}"
        {{- end }}
        {{ range service "dask-scheduler-${name}" -}}
          SNOOP_DASK_SCHEDULER_URL = "tcp://{{.Address}}:{{.Port}}"
        {{- end }}
        EOF
        destination = "local/snoop.env"
        env = true
      }
      resources {
        memory = ${worker_memory_limit}
        network {
          mbits = 1
          port "dashboard" {}
          port "worker" {}
        }
      }
      service {
        name = "dask-worker-ui-${name}"
        port = "dashboard"
        tags = ["snoop-/_dask/${name}/worker"]
        check {
          name = "http"
          initial_status = "critical"
          path = "/_dask/${name}/worker/"
          type = "http"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
      service {
        name = "dask-worker-${name}"
        port = "worker"
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    ${ promtail_task() }
  }

  group "api" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "snoop" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      constraint {
        attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('hoover-snoop2')}"
        args = ["sh", "/local/startup.sh"]
        volumes = [
          ${hoover_snoop2_repo}
          "{% raw %}${meta.liquid_collections}{% endraw %}/${name}:/opt/hoover/collection",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/collections/${name}/blobs:/opt/hoover/snoop/blobs",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "snoop-${name}-api"
        }
      }
      env {
        SNOOP_COLLECTION_ROOT = "/opt/hoover/collection"
        SNOOP_TASK_PREFIX = "${name}"
        SNOOP_ES_INDEX = "${name}"
      }
      template {
        data = <<-EOF
        #!/bin/sh
        set -ex
        if [ -z "$SNOOP_ES_URL" ] || [ -z "$SNOOP_DB" ]; then
          echo "incomplete configuration!"
          sleep 5
          exit 1
        fi
        date
        ./manage.py migrate --noinput
        ./manage.py healthcheck

        date
        exec /runserver
        EOF
        env = false
        destination = "local/startup.sh"
      }
      env {
        SNOOP_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8765/_es"
        SNOOP_STATS_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8765/_es"
        SNOOP_STATS_ES_PREFIX = ".hoover-snoopstats-"
      }
      template {
        data = <<-EOF
        {{- if keyExists "liquid_debug" }}
          DEBUG = {{ key "liquid_debug" | toJSON }}
        {{- end }}
        {{- with secret "liquid/collections/${name}/snoop.django" }}
          SECRET_KEY = {{.Data.secret_key | toJSON }}
        {{- end }}
        {{- range service "snoop-${name}-pg" }}
          SNOOP_DB = "postgresql://snoop:
          {{- with secret "liquid/collections/${name}/snoop.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{.Address}}:{{.Port}}/snoop"
        {{- end }}

        {{- range service "snoop-${name}-rabbitmq" }}
          SNOOP_AMQP_URL = "amqp://{{.Address}}:{{.Port}}"
        {{- end }}
        SNOOP_HOSTNAME = "${name}.snoop.{{ key "liquid_domain" }}"
        {{- range service "zipkin" }}
          TRACING_URL = "http://{{.Address}}:{{.Port}}"
        {{- end }}
        {{ range service "dask-scheduler-${name}" -}}
          SNOOP_DASK_SCHEDULER_URL = "tcp://{{.Address}}:{{.Port}}"
        {{- end }}
        EOF
        destination = "local/snoop.env"
        env = true
      }
      resources {
        memory = 400
        cpu = 200
        network {
          mbits = 1
          port "http" {}
        }
      }
      service {
        name = "snoop-${name}"
        port = "http"
        tags = ["snoop-/${name} strip=/${name} host=${name}.snoop.${liquid_domain}"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/collection/json"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["${name}.snoop.${liquid_domain}"]
          }
        }
      }
    }

    ${ promtail_task() }
  }

  group "airflow-scheduler" {
    task "scheduler" {
      driver = "docker"
      config {
        image = "${config.image('hoover-snoop2')}"
        args = ["bash", "/local/startup.sh"]
        volumes = [ ${hoover_snoop2_repo} ]

        labels {
          liquid_task = "airflow-scheduler-${name}"
        }
      }

      template {
        data = <<-EOF
          #!/bin/bash
          exec airflow scheduler --pid /local/pid.txt
          EOF
        env = false
        destination = "local/startup.sh"
      }

      ${ airflow_env_template() }

      resources {
        memory = 700
        cpu = 200
        network {
          mbits = 1
        }
      }
    }
  }

  group "airflow-webserver" {
    task "webserver" {
      driver = "docker"
      config {
        image = "${config.image('hoover-snoop2')}"
        force_pull = "true"

        args = ["bash", "/local/startup.sh"]
        volumes = [ ${hoover_snoop2_repo} ]

        port_map {
          http = 8080
        }
        labels {
          liquid_task = "airflow-webserver-${name}"
        }
      }

      template {
        data = <<-EOF
          #!/bin/bash
          airflow upgradedb
          airflow connections --delete --conn_id minio_logs || true
          airflow connections --add --conn_id minio_logs --conn_type s3 --conn_extra "$AIRFLOW_MINIO_LOGS_EXTRA"
          exec airflow webserver --pid /local/pid.txt
          EOF
        env = false
        destination = "local/startup.sh"
      }

      ${ airflow_env_template() }

      resources {
        memory = 900
        cpu = 200
        network {
          mbits = 1
          port "http" {}
        }
      }
      service {
        name = "airflow-webserver-${name}"
        tags = ["snoop-/_airflow/${name}"]
        port = "http"
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/_airflow/${name}/health"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
