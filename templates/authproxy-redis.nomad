{% from '_lib.hcl' import continuous_reschedule, task_logs, group_disk with context -%}

job "redis" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  group "authproxy-redis" {
    ${ continuous_reschedule() }
    ${ group_disk() }
  
    task "authproxy-redis" {
      ${ task_logs() }
  
      driver = "docker"
      config {
        image = "${config.image('authproxy-redis')}"
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
        tags = ["fabio-:9993 proto=tcp"]

        check {
          name = "alive"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
        check_restart {
          limit = 5
          grace = "480s"
        }
      }
    }
  }
}
