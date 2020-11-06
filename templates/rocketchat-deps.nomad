{% from '_lib.hcl' import shutdown_delay, continuous_reschedule, group_disk, task_logs with context -%}

job "rocketchat-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 30

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
        image = "mongo:3.2"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/rocketchat/mongo/data:/data/db",
        ]
        args = ["mongod", "--smallfiles", "--replSet", "rs01"]
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
          port "mongo" {}
        }
      }
      service {
        name = "rocketchat-mongo"
        port = "mongo"
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
