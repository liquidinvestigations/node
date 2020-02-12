{% from '_lib.hcl' import group_disk, task_logs -%}

job "hoover-ui" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 80

  group "ui" {
    ${ group_disk() }

    task "ui" {
      leader = true

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('hoover-ui')}"
        volumes = [
          ${hoover_ui_repo}
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover-ui/build:/opt/hoover/ui/build",
        ]
        labels {
          liquid_task = "hoover-ui"
        }
        args = ["npm", "run", "build"]
      }
      resources {
        memory = 900
      }
    }
  }
}
