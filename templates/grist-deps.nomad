{% from '_lib.hcl' import set_pg_password_template, shutdown_delay, authproxy_group, task_logs, group_disk, continuous_reschedule with context -%}

job "grist-deps" {
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
        image = "postgres:14"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/grist/postgres:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "grist-pg"
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
        POSTGRES_DB = "grist"
        POSTGRES_USER = "grist"
        {{- with secret "liquid/grist/grist.postgres" }}
          POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        EOF
        destination = "local/pg.env"
        env = true
      }

      ${ set_pg_password_template('grist') }

      resources {
        cpu = 100
        memory = 300
        network {
          mbits = 1
          port "pg" {}
        }
      }

      service {
        name = "grist-pg"
        port = "pg"
        tags = ["fabio-:${config.port_grist_pg} proto=tcp"]
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

  group "grist-redis" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "grist-redis" {
      ${ task_logs() }
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      ${ shutdown_delay() }

      driver = "docker"
      config {
        image = "${config.image('grist-redis')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/grist/redis:/data",
        ]
        port_map {
          redis = 6379
        }
        labels {
          liquid_task = "grist-redis"
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
        name = "grist-redis"
        port = "redis"
        tags = ["fabio-:${config.port_grist_redis} proto=tcp"]

        check {
          name = "alive"
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

  group "grist-minio" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "grist-minio" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "${config.image('minio2024')}"
        entrypoint = ["sh"]
        args =  ["-c", "minio server --console-address :9001 /data/{1..4}"]
        port_map {
          s3 = 9000
          console = 9001
        }
        labels {
          liquid_task = "grist-minio"
        }
        memory_hard_limit = 5000
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/grist/minio.2024.x4:/data",
        ]
      }

      env {
        MINIO_UPDATE = "off"
        MINIO_API_REQUESTS_MAX = "600"
        MINIO_API_REQUESTS_DEADLINE = "2m"
        MINIO_DRIVE_SYNC = "on"
        GOMAXPROCS = "20"
      }

      resources {
        memory = 3500
        cpu = 1000
        network {
          mbits = 1
          port "s3" {}
          port "console" {}
        }
      }

      template {
        data = <<EOF
          {{- with secret "liquid/grist/minio.user" }}
              MINIO_ROOT_USER = {{.Data.secret_key | toJSON }}
          {{- end }}
          {{- with secret "liquid/grist/minio.password" }}
              MINIO_ROOT_PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/minio.env"
        env = true
      }

      service {
        name = "grist-minio-s3"
        port = "s3"
        tags = ["fabio-:${config.port_grist_s3} proto=tcp"]

        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }

      service {
        name = "grist-minio-console"
        port = "console"
        tags = ["fabio-/grist_minio_conosole/ strip=/grist_minio_conosole"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
