job "hoover-ui" {
  datacenters = ["dc1"]
  type = "batch"

  group "ui" {
    task "ui" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-ui"
        volumes = [
          "/var/local/liquid/volumes/hoover-ui/build:/opt/hoover/ui/build",
        ]
        labels {
          liquid_task = "hoover-ui"
        }
        args = ["npm", "run", "build"]
      }
      resources {
        memory = 1024
      }
    }
  }
}
