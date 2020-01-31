{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule, set_pg_password_template, promtail_task with context -%}

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

  group "db" {
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

  group "dask-scheduler" {
    ephemeral_disk {
      migrate = true
      size    = "500"
      sticky  = true
    }
    task "scheduler" {
      driver = "docker"
      config {
        image = "daskdev/dask:2.9.2"
        args = ["dask-scheduler", "--local-directory", "/data"]
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
      env {
        "DASK_DISTRIBUTED__ADMIN__TICK__INTERVAL" = "1000ms"
        "DASK_DISTRIBUTED__WORKER__PROFILE__INTERVAL" = "100ms"
        "DASK_DISTRIBUTED__WORKER__PROFILE__CYCLE" = "10000ms"
        "DASK_DISTRIBUTED__SCHEDULER__WORK_STEALING" = "True"
        "DASK_DISTRIBUTED__SCHEDULER__ALLOWED_FAILURES" = "2"
      }
      resources {
        memory = 400
        cpu = 200
        network {
          mbits = 1
          port "http" {}
          port "tcp" {}
        }
      }
      service {
        name = "dask-scheduler-${name}-ui"
        port = "http"
        check {
          name = "http"
          initial_status = "critical"
          path = "/"
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

