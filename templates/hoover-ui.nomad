{% from '_lib.hcl' import group_disk, task_logs -%}

job "hoover-ui" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 90

  group "ui" {
    ${ group_disk() }

    task "ui" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-ui"
        volumes = [
          "${liquid_volumes}/hoover-ui/build:/opt/hoover/ui/build",
        ]
        labels {
          liquid_task = "hoover-ui"
        }
        args = ["npm", "run", "build"]
      }
      resources {
        memory = 1000
      }
    }
  }
}
