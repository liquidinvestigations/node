{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule, promtail_task -%}

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

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      constraint {
        attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('liquid-nextcloud')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud/nextcloud:/var/www/html",
          "{% raw %}${meta.liquid_collections}{% endraw %}/uploads/data:/var/www/html/data/uploads/files",
        ]
        args = ["sudo", "-Eu", "www-data", "bash", "/local/periodic.sh"]
        labels {
          liquid_task = "nextcloud-migrate"
        }
      }
      template {
        data = <<EOF
          set -ex
          cd /var/www/html
          php occ files:scan --all
        EOF
        destination = "local/periodic.sh"
      }
      env {
        TIMESTAMP = "${config.timestamp}"
      }
      resources {
        memory = 100
        cpu = 200
      }
    }

    ${ promtail_task() }
  }
}
