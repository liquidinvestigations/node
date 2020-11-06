{% from '_lib.hcl' import shutdown_delay, authproxy_group, task_logs, group_disk with context -%}

job "codimd-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 66

  group "db" {
    ${ group_disk() }
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
        image = "postgres:11.5"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/codimd/postgres:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "codimd-pg"
        }
        port_map {
          pg = 5432
        }
        # 128MB, the default postgresql shared_memory config
        shm_size = 134217728
        memory_hard_limit = 1000
      }
      template {
        data = <<-EOF
        POSTGRES_DB = "codimd"
        POSTGRES_USER = "codimd"
        {{- with secret "liquid/codimd/codimd.postgres" }}
          POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        EOF
        destination = "local/pg.env"
        env = true
      }
      resources {
        cpu = 100
        memory = 300
        network {
          mbits = 1
          port "pg" {}
        }
      }
      service {
        name = "codimd-pg"
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
