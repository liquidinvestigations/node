{% from '_lib.hcl' import continuous_reschedule, task_logs, group_disk, shutdown_delay with context -%}

job "redis" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  group "authproxy-redis" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "authproxy-redis" {
      ${ task_logs() }
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      ${ shutdown_delay() }

      driver = "docker"
      config {
        image = "${config.image('authproxy-redis')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/auth/redis/data:/data",
        ]
        port_map {
          redis = 6379
        }
        labels {
          liquid_task = "authproxy-redis"
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
        name = "authproxy-redis"
        port = "redis"
        tags = ["fabio-:${config.port_authproxy_redis} proto=tcp"]

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
}
