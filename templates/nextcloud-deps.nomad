{% from '_lib.hcl' import shutdown_delay, group_disk, task_logs with context -%}

job "nextcloud-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  group "maria" {
    ${ group_disk() }
    task "maria" {
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
        image = "mariadb:10.4"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud/mysql:/var/lib/mysql",
        ]
        labels {
          liquid_task = "nextcloud-maria"
        }
        port_map {
          maria = 3306
        }
        memory_hard_limit = 750
      }
      template {
        data = <<-EOF
        MYSQL_RANDOM_ROOT_PASSWORD = "yes"
        MYSQL_DATABASE = "nextcloud"
        MYSQL_USER = "nextcloud"
        {{- with secret "liquid/nextcloud/nextcloud.maria" }}
          MYSQL_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        EOF
        destination = "local/maria.env"
        env = true
      }
      resources {
        cpu = 100
        memory = 250
        network {
          mbits = 1
          port "maria" {
            static = 8767
          }
        }
      }
      service {
        name = "nextcloud-maria"
        port = "maria"
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
