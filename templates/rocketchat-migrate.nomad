{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "rocketchat-migrate" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 30

  group "configuration" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "caboose" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('liquid-caboose')}"
        args = ["python", "/local/rocketchat-caboose.py"]
        labels {
          liquid_task = "rocketchat-caboose"
        }
      }
      template {
        data = <<-EOF
# Auto-generated by rocketchat migrate script
# Timestamp: ${config.timestamp}
{% include 'rocketchat-caboose.py' %}
        EOF
        destination = "local/rocketchat-caboose.py"
      }
      template {
        data = <<-EOF
          {{- range service "rocketchat-mongo" }}
            MONGO_ADDRESS = {{.Address | toJSON }}
            MONGO_PORT = {{.Port | toJSON }}
          {{- end }}
        EOF
        destination = "local/liquid.env"
        env = true
      }
    }
  }
}
