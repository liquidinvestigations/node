{% from '_lib.hcl' import set_pg_password_template, shutdown_delay, authproxy_group, task_logs, group_disk, continuous_reschedule with context -%}

job "prophecies-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "db" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "postgres" {
      ${ task_logs() }
      leader = true

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = 100
      }

      driver = "docker"
      ${ shutdown_delay() }

      config {
        image = "postgres:16"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/prophecies/postgres:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "prophecies-pg"
        }
        port_map {
          pg = 5432
        }
        # 128MB, the default postgresql shared_memory config
        shm_size = 134217728
        memory_hard_limit = 9000
      }

      template {
        data = <<-EOF
        POSTGRES_DB = "prophecies"
        POSTGRES_USER = "prophecies"
        {{- with secret "liquid/prophecies/prophecies.postgres" }}
          POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        EOF
        destination = "local/pg.env"
        env = true
      }

      ${ set_pg_password_template('prophecies') }

      resources {
        cpu = 100
        memory = 300
        network {
          mbits = 1
          port "pg" {}
        }
      }

      service {
        name = "prophecies-pg"
        port = "pg"
        tags = ["fabio-:${config.port_prophecies_pg} proto=tcp"]
        check {
          name = "pg_isready"
          type = "script"
          command = "/bin/sh"
          args = ["-c", "pg_isready"]
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
