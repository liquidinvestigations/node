{% from '_lib.hcl' import group_disk, task_logs -%}

job "zipkin" {
  datacenters = ["dc1"]
  type = "service"
  priority = 25

  group "zipkin" {
    ${ group_disk() }

    task "zipkin" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "openzipkin/zipkin"
        labels {
          liquid_task = "zipkin"
        }
        port_map {
          http = 9411
        }
      }
      resources {
        memory = 1000
        cpu = 200
        network {
          mbits = 1
          port "http" {}
        }
      }
      service {
        name = "zipkin"
        port = "http"
        check {
          name = "zipkin alive on http"
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
