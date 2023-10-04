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

      resources {
        memory = 150
      }

      env {
        LIQUID_DOMAIN = "${liquid_domain}"
        HOOVER_ENABLED = "${ config.is_app_enabled('hoover') }"
        ROCKETCHAT_ENABLED = "${ config.is_app_enabled('rocketchat') }"
        CODIMD_ENABLED = "${ config.is_app_enabled('codimd') }"
        WIKIJS_ENABLED = "${ config.is_app_enabled('wikijs') }"
      }

      template {
        data = <<-EOF
        ROCKETCHAT_URL = 'http://{{ env "attr.unique.network.ip-address" }}:${config.port_rocketchat}/'
        {{- with secret "liquid/rocketchat/adminuser" }}
            ROCKETCHAT_SECRET = {{.Data.pass }}
        {{- end }}
        EOF
        destination = "local/liquid-deleteuser.env"
        env = true
      }

      template {
        left_delimiter = "DELIMITER_L"
        right_delimiter = "DELIMITER_R"
        destination = "local/delete_rocket_user.py"
        perms = "755"
        data = <<-EOF
{% include 'scripts/delete_rocket_user.py' %}
        EOF
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
