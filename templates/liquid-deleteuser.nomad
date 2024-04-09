job "liquid-deleteuser" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 99

  parameterized {
    meta_required = ["USERNAME"]
    }

  group "deleteuser" {
    task "script" {
      leader = true

      driver = "raw_exec"

      config {
        command = "sh"
        args    = [
                "local/deleteuser.sh",
                "{% raw %}${NOMAD_META_USERNAME}{% endraw %}"
                ]
      }

      env {
        LIQUID_DOMAIN = "${liquid_domain}"
        HOOVER_ENABLED = "${ config.is_app_enabled('hoover') }"
        CODIMD_ENABLED = "${ config.is_app_enabled('codimd') }"
        WIKIJS_ENABLED = "${ config.is_app_enabled('wikijs') }"
        NEXTCLOUD28_ENABLED = "${ config.is_app_enabled('nextcloud28') }"
      }

      template {
        destination = "local/deleteuser.sh"
        perms = "755"
        data = <<-EOF
{% include 'scripts/deleteuser.sh' %}
        EOF
      }
    }
  }
}
