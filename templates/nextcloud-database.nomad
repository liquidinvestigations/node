{% from '_lib.hcl' import shutdown_delay, authproxy_group with context -%}

job "nextcloud-database" {
  datacenters = ["dc1"]
  type = "service"
  priority = 100

  group "nextcloud-database" {
    task "nextcloud-database" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      ${ shutdown_delay() }
      config {
        image = "postgres:12"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud/postgres12:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "nextcloud-pg"
        }
        port_map {
          pg = 5432
        }
        # 128MB, the default postgresql shared_memory config
        shm_size = 134217728
      }
      template {
        data = <<-EOF
        POSTGRES_DB = "nextcloud"
        POSTGRES_USER = "nextcloudAdmin"

        {{- with secret "liquid/nextcloud/nextcloud.postgres" }}
          POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        EOF
        destination = "local/db.env"
        env = true
      }
      resources {
        cpu = 100
        memory = 500
        network {
          mbits = 1
          # save port as static because there's no simple way to update it
          port "pg" {
            static = 8666
          }
        }
      }
      service {
        name = "nextcloud-pg"
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
