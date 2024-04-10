{% from '_lib.hcl' import set_pg_password_template, shutdown_delay, authproxy_group, task_logs, group_disk, continuous_reschedule with context -%}

job "bbb-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "bbb-pg" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "bbb-pg" {
      ${ task_logs() }
      leader = false

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
        image = "${config.image('bbb-pg-15')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/bbb/postgres/${config.liquid_domain}-pg-15:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "bbb-pg"
        }
        port_map {
          bbb_pg = 5432
        }
        # 128MB, the default postgresql shared_memory config
        shm_size = 134217728
        memory_hard_limit = 1000
      }

      template {
        data = <<-EOF
        POSTGRES_DB = "greenlight_production"
        POSTGRES_USER = "greenlight"
        {{- with secret "liquid/bbb/bbb.postgres" }}
          POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        POSTGRES_INITDB_ARGS = "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
        EOF
        destination = "local/pg.env"
        env = true
      }
      ${ set_pg_password_template('bbb') }

      resources {
        cpu = 100
        memory = 300
        network {
          mbits = 1
          port "bbb_pg" {}
        }
      }

      service {
        name = "bbb-pg"
        port = "bbb_pg"
        tags = ["fabio-:${config.port_bbb_pg} proto=tcp"]
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

  group "bbb-redis" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "bbb-redis" {
      ${ task_logs() }
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      ${ shutdown_delay() }

      driver = "docker"
      config {
        image = "${config.image('bbb-redis')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/bbb/redis/data:/data",
        ]
        port_map {
          redis = 6379
        }
        labels {
          liquid_task = "bbb-redis"
        }
      }

      resources {
        cpu = 500
        memory = 512
        network {
          port "redis" {}
          mbits = 1
        }
      }

      service {
        name = "bbb-redis"
        port = "redis"
        tags = ["fabio-:${config.port_bbb_redis} proto=tcp"]

        check {
          name = "bbb-redis-alive"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
        check_restart {
          limit = 5
          grace = "980s"
        }
      }
    }
  }
}
