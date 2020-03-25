{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "nextcloud-periodic" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 49
  periodic {
    cron  = "@hourly"
    prohibit_overlap = true
  }

  group "periodic" {
    ${ group_disk() }

    ${ continuous_reschedule() }

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
        command = "sh"
        args    = ["local/periodic.sh"]
      }

      template {
        destination = "local/periodic.sh"
        perms = "755"
        data = <<-EOF
          #!/bin/sh
          set -ex

          ${exec_command('nextcloud:nextcloud', 'sudo', '-Eu', 'www-data', 'php', 'occ', 'files:scan', '--all')}
        EOF
      }
    }
  }
}
