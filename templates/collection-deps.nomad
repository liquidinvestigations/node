{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule, set_pg_password_template with context -%}

job "collection-${name}-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  group "queue" {
    ${ group_disk() }

    task "rabbitmq" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "rabbitmq:3.7.3"
        volumes = [
          "${liquid_volumes}/collections/${name}/rabbitmq/rabbitmq:/var/lib/rabbitmq",
        ]
        port_map {
          amqp = 5672
        }
        labels {
          liquid_task = "snoop-${name}-rabbitmq"
        }
      }
      resources {
        memory = 700
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
  }

  group "db" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "pg" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "${liquid_volumes}/collections/${name}/pg/data:/var/lib/postgresql/data",
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
        cpu = 400
        memory = 400
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
  }
}

