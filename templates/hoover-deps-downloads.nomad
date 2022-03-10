{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "hoover-deps-downloads" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 99

  group "dummy-task" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "dummy-task" {
      leader = true

      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      constraint {
        attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
        operator = "is_set"
      }

      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["-c", "echo OK"]
      }
    }
  }
}
