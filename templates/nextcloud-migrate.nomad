{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "nextcloud-migrate" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 45

  group "migrate" {
    ${ group_disk() }

    reschedule {
      attempts       = 6
      interval       = "1h"
      delay          = "40s"
      delay_function = "exponential"
      max_delay      = "300s"
      unlimited      = false
    }

    task "script" {
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
        command = "bash"
        args    = ["local/migrate.sh"]
      }

      env {
        TIMESTAMP = "${config.timestamp}"
      }

      template {
        destination = "local/migrate.sh"
        perms = "755"
        data = <<-EOF
          #!/bin/sh
          set -ex

          container_id="$(docker ps -q -f label=liquid_task=nextcloud)"
          docker exec $container_id sudo -Eu www-data bash /local/setup.sh
        EOF
      }
    }
  }
}
