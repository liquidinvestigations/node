{% from '_lib.hcl' import set_pg_password_template, shutdown_delay, authproxy_group, task_logs, group_disk, continuous_reschedule with context -%}

job "bbb" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "bbb" {
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
        image = "postgres:15"
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

    task "greenlight" {
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

      template {
        data = <<-EOF
        {{- with secret "liquid/bbb/bbb.postgres" }}
        DATABASE_URL = "postgres://greenlight:{{.Data.secret_key | toJSON }}@{{env "attr.unique.network.ip-address"}}:${config.port_bbb_pg}/greenlight_production"
        {{- end }}
        REDIS_URL = "redis://{{ env "attr.unique.network.ip-address"}}:${config.port_bbb_redis}"
        BIGBLUEBUTTON_ENDPOINT = "${config.bbb_endpoint}"
        BIGBLUEBUTTON_SECRET = "${config.bbb_secret}"
        {{- with secret "liquid/bbb/bbb.secret_key_base" }}
        SECRET_KEY_BASE = {{.Data.secret_key | toJSON }}
        {{- end }}
        RELATIVE_URL_ROOT = "/"
        {{- with secret "liquid/bbb/auth.oauth2" }}
        OPENID_CONNECT_CLIENT_ID = {{.Data.client_id | toJSON }}
        OPENID_CONNECT_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
        {{- end }}
        OPENID_CONNECT_ISSUER="${config.liquid_http_protocol}://${liquid_domain}"
        OPENID_CONNECT_REDIRECT="${config.liquid_http_protocol}://bbb.${liquid_domain}/"
        EOF
        destination = "local/greenlight.env"
        env = true
      }

      config {
        image = "${config.image('bbb-gl')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/bbb/greenlight/data/:/usr/src/app/storage/",
        ]
        port_map {
          bbb-gl = 3000
        }
        labels {
          liquid_task = "bbb_greenlight"
        }
        memory_hard_limit = 2000
      }

      resources {
        memory = 450
        cpu = 150
        network {
          mbits = 1
          port "bbb-gl" {}
        }
      }

      service {
        name = "bbb-gl"
        port = "bbb-gl"
        tags = [
        "traefik.enable=true",
        "traefik.frontend.rule=Host:bbb.${liquid_domain}",
        "fabio-:${config.port_bbb_gl} proto=tcp"
        ]
        check {
          name = "bbb-gl"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
