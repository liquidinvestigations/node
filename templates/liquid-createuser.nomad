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
        WIKIJS_URL = 'http://{{ env "attr.unique.network.ip-address" }}:${config.port_wikijs}/'
        {{- with secret "liquid/rocketchat/adminuser" }}
            WIKIJS_API_TOKEN = {{.Data.pass }}
        {{- end }}
        EOF
        destination = "local/liquid-deleteuser.env"
        env = true
      }

      template {
        left_delimiter = "DELIMITER_L"
        right_delimiter = "DELIMITER_R"
        destination = "local/create_rocket_user.py"
        perms = "755"
        data = <<-EOF
{% include 'scripts/create_rocket_user.py' %}
        EOF
      }

      template {
        left_delimiter = "DELIMITER_L"
        right_delimiter = "DELIMITER_R"
        destination = "local/create_wikijs_user.py"
        perms = "755"
        data = <<-EOF
{% include 'scripts/create_wikijs_user.py' %}
        EOF
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
