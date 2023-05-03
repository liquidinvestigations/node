job "liquid-deletegroup" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 99

  parameterized {
    meta_required = ["GROUP"]
    }

  group "deletegroup" {
    task "script" {
      leader = true

      driver = "raw_exec"

      config {
        command = "sh"
        args    = [
                "local/deletegroup.sh",
                "{% raw %}${NOMAD_META_GROUP}{% endraw %}"
                ]
      }

      env {
        LIQUID_DOMAIN = "${liquid_domain}"
        WIKIJS_ENABLED = "${ config.is_app_enabled('wikijs') }"
      }


      template {
        destination = "local/deletegroup.sh"
        perms = "755"
        data = <<-EOF
{% include 'scripts/deletegroup.sh' %}
        EOF
      }
    }
  }
}
