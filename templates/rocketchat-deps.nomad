{% from '_lib.hcl' import shutdown_delay, continuous_reschedule, group_disk, task_logs with context -%}

job "rocketchat-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

  group "db" {
    ${ group_disk() }
    task "mongo" {
      ${ task_logs() }
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      ${ shutdown_delay() }
      config {
        image = "${config.image('rocketchat-mongo')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/rocketchat/mongo-4.4/data:/data/db",
        ]
        args = ["mongod", "--replSet", "rs01", "--bind_ip_all", "--port", "27017"]
        labels {
          liquid_task = "rocketchat-mongo"
        }
        port_map {
          mongo = 27017
        }
        memory_hard_limit = 2000
      }
      resources {
        memory = 500
        cpu = 200
        network {
          mbits = 1
          port "mongo" {
            static = 27017
          }
        }
      }
      service {
        name = "rocketchat-mongo"
        port = "mongo"
        tags = ["fabio-:${config.port_rocketchat_mongo} proto=tcp"]
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
