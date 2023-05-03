job "liquid-creategroup" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 99

  parameterized {
    meta_required = ["GROUP"]
    }

  group "creategroup" {
    task "script" {
      leader = true

      driver = "raw_exec"

      config {
        command = "sh"
        args    = [
                "local/creategroup.sh",
                "{% raw %}${NOMAD_META_GROUP}{% endraw %}"
                ]
      }

      env {
        LIQUID_DOMAIN = "${liquid_domain}"
        WIKIJS_ENABLED = "${ config.is_app_enabled('wikijs') }"
      }


      template {
        left_delimiter = "DELIMITER_L"
        right_delimiter = "DELIMITER_R"
        destination = "local/creategroup.sh"
        perms = "755"
        data = <<-EOF
        {% include 'scripts/creategroup.sh' %}
        EOF
      }
    }
  }
}
