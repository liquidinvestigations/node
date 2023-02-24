{% from '_lib.hcl' import shutdown_delay, group_disk, task_logs, continuous_reschedule, set_pg_password_template, set_pg_drop_template with context -%}

job "wikijs-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "wikijs-pg" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "wikijs-pg" {
      ${ task_logs() }

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
        image = "postgres:11"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/wikijs/wikijs-pg-11/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "wikijs-pg"
        }
        port_map {
          pg = 5432
        }
        # 128MB, the default postgresql shared_memory config
        shm_size = 134217728
        memory_hard_limit = 5200
      }

      template {
        data = <<EOF
          POSTGRES_USER = "wikijs"
          POSTGRES_DATABASE = "wikijs"
          {{- with secret "liquid/wikijs/wikijs.postgres" }}
            POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/postgres.env"
        env = true
      }

      ${ set_pg_password_template('wikijs') }
      ${ set_pg_drop_template('wikijs') }

      resources {
        memory = 1200
        network {
          mbits = 1
          port "pg" {}
        }
      }
      service {
        name = "wikijs-pg"
        port = "pg"
        tags = ["fabio-:${config.port_wikijs_pg} proto=tcp"]
        check {
          name = "pg_isready"
          type = "script"
          command = "/bin/sh"
          args = ["-c", "pg_isready -U wikijs"]
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}