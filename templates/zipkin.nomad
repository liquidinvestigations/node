job "zipkin" {
  datacenters = ["dc1"]
  type = "service"

  group "zipkin" {
    task "zipkin" {
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
        network {
          port "http" {}
        }
      }
      service {
        name = "zipkin"
        port = "http"
      }
    }
  }
}
