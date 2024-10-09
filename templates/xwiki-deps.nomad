{% from '_lib.hcl' import shutdown_delay, group_disk, task_logs, continuous_reschedule, set_pg_password_template, set_pg_drop_template with context -%}

job "xwiki-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "xwiki-pg" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "xwiki-pg" {
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
          "{% raw %}${meta.liquid_volumes}{% endraw %}/xwiki/xwiki-pg-11/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "xwiki-pg"
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
          POSTGRES_USER = "xwiki"
          POSTGRES_DATABASE = "xwiki"
          {{- with secret "liquid/xwiki/xwiki.postgres" }}
            POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/postgres.env"
        env = true
      }

      ${ set_pg_password_template('xwiki') }
      ${ set_pg_drop_template('xwiki') }

      resources {
        memory = 400
        cpu = 100
        network {
          mbits = 1
          port "pg" {}
        }
      }
      service {
        name = "xwiki-pg"
        port = "pg"
        tags = ["fabio-:${config.port_xwiki_pg} proto=tcp"]
        check {
          name = "pg_isready"
          type = "script"
          command = "/bin/sh"
          args = ["-c", "pg_isready -U xwiki"]
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
