job "liquid" {
  datacenters = ["dc1"]
  type = "service"

  group "core" {

    task "core" {
      driver = "docker"

      config {
        image = "liquidinvestigations/core"
        port_map {
          web = 8000
        }
      }

      service {
        name = "core-app"
        tags = ["global", "app"]
        port = "web"
      }

      resources {
        network {
          port "web" {
            static = 10000
          }
        }
      }
    }

  }
}
