job "liquid-createuser" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 99

  parameterized {
    meta_required = ["USERNAME"]
    }

  group "createuser" {
    task "script" {
      leader = true

      driver = "raw_exec"

      config {
        command = "sh"
        args    = [
                "local/createuser.sh",
                "{% raw %}${NOMAD_META_USERNAME}{% endraw %}"
                ]
      }

      env {
        LIQUID_DOMAIN = "${liquid_domain}"
        HOOVER_ENABLED = "${ config.is_app_enabled('hoover') }"
        CODIMD_ENABLED = "${ config.is_app_enabled('codimd') }"
        WIKIJS_ENABLED = "${ config.is_app_enabled('wikijs') }"
      }

      template {
        left_delimiter = "DELIMITER_L"
        right_delimiter = "DELIMITER_R"
        destination = "local/createuser.sh"
        perms = "755"
        data = <<-EOF
        {% include 'scripts/createuser.sh' %}
        EOF
      }
    }
  }
}
