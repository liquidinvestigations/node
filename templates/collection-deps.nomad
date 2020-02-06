{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule, set_pg_password_template, promtail_task, airflow_env_template, dask_env_template with context -%}

job "collection-${name}-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  {% if workers %}
  group "queue" {
    ${ group_disk() }

    task "rabbitmq" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "rabbitmq:3.7.3"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/collections/${name}/rabbitmq/rabbitmq:/var/lib/rabbitmq",
        ]
        port_map {
          amqp = 5672
        }
        labels {
          liquid_task = "snoop-${name}-rabbitmq"
        }
      }
      resources {
        memory = ${rabbitmq_memory_limit}
        cpu = 150
        network {
          mbits = 1
          port "amqp" {}
        }
      }
      service {
        name = "snoop-${name}-rabbitmq"
        port = "amqp"
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
  {% endif %}

  group "snoop-db" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "pg" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/collections/${name}/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "snoop-${name}-pg"
        }
        port_map {
          pg = 5432
        }
      }
      template {
        data = <<EOF
          POSTGRES_USER = "snoop"
          POSTGRES_DATABASE = "snoop"
          {{- with secret "liquid/collections/${name}/snoop.postgres" }}
            POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/postgres.env"
        env = true
      }
      ${ set_pg_password_template('snoop') }
      resources {
        cpu = 200
        memory = 300
        network {
          mbits = 1
          port "pg" {}
        }
      }
      service {
        name = "snoop-${name}-pg"
        port = "pg"
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

  group "airflow-db" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "pg" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/collections/${name}/airflow-pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "snoop-${name}-airflow-pg"
        }
        port_map {
          pg = 5432
        }
      }
      template {
        data = <<EOF
          POSTGRES_USER = "airflow"
          POSTGRES_DB = "airflow"
          {{- with secret "liquid/collections/${name}/airflow.postgres" }}
            POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/postgres.env"
        env = true
      }
      ${ set_pg_password_template('airflow') }
      resources {
        cpu = 200
        memory = 300
        network {
          mbits = 1
          port "pg" {}
        }
      }
      service {
        name = "snoop-${name}-airflow-pg"
        port = "pg"
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

  group "logs-minio" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "minio" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "minio/minio:RELEASE.2020-01-25T02-50-51Z"
        args = ["server", "/data"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/collections/${name}/airflow-minio/data:/data",
        ]
        labels {
          liquid_task = "snoop-${name}-airflow-minio"
        }
        port_map {
          http = 9000
        }
      }
      template {
        data = <<EOF
          {{- with secret "liquid/collections/${name}/logs.minio.key" }}
            MINIO_ACCESS_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}

          {{- with secret "liquid/collections/${name}/logs.minio.secret" }}
            MINIO_SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/postgres.env"
        env = true
      }
      ${ set_pg_password_template('airflow') }
      resources {
        cpu = 200
        memory = 300
        network {
          mbits = 1
          port "http" {}
        }
      }
      service {
        name = "snoop-${name}-airflow-minio"
        port = "http"
        check {
          name = "http"
          type = "http"
          initial_status = "critical"
          path = "/minio/health/live"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    ${ promtail_task() }
  }

  group "dask-scheduler" {
    task "scheduler" {
      driver = "docker"
      config {
        image = "${config.image('hoover-snoop2')}"
        force_pull = "true"

        args = ["dask-scheduler", "--local-directory", "/data", "--dashboard-prefix", "/_dask/${name}/scheduler"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/collections/${name}/dask-scheduler:/data",
        ]

        port_map {
          tcp = 8786
          http = 8787
        }
        labels {
          liquid_task = "dask-scheduler-${name}"
        }
      }

      ${ dask_env_template() }

      resources {
        memory = 500
        cpu = 400
        network {
          mbits = 1
          port "http" {}
          port "tcp" {}
        }
      }
      service {
        name = "dask-scheduler-${name}-ui"
        port = "http"
        tags = ["snoop-/_dask/${name}/scheduler"]
        check {
          name = "http"
          initial_status = "critical"
          path = "/_dask/${name}/scheduler/"
          type = "http"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
      service {
        name = "dask-scheduler-${name}"
        port = "tcp"
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


  group "dask-notebook" {
    task "notebook" {
      driver = "docker"
      config {
        image = "daskdev/dask-notebook:2.9.2"

        port_map {
          http = 8888
        }
        labels {
          liquid_task = "dask-notebook"
        }
      }

      template {
        data = <<-EOF
        DASK_SCHEDULER_ADDRESS={{- range service "dask-scheduler-${name}" -}}tcp://{{.Address}}:{{.Port}}{{- end -}}
        EOF
        env = true
        destination = "local/env.sh"
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
        name = "dask-notebook"
        port = "http"
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
        check_restart {
          limit = 5
          grace = "180s"
        }
      }
    }

    ${ promtail_task() }
  }
}

