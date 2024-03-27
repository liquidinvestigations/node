{% from '_lib.hcl' import shutdown_delay, group_disk, task_logs, continuous_reschedule with context -%}

job "collabora" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "collabora" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "collabora" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      ${ shutdown_delay() }
      config {
        image = "collabora/code:23.05.8.2.1"
        entrypoint = ["/bin/bash", "/local/collabora-entrypoint.sh"]
        port_map {
          http = 9980
        }
        labels {
          liquid_task = "collabora"
        }
        memory_hard_limit = 16384
      }


      env {
        server_name = "collabora.${config.liquid_domain}"
      }

      template {
        data = <<-EOF
        {% if not config.https_enabled %}
            extra_params = "--o:ssl.enable=false --o:ssl.termination=false"
        {% else %}
            extra_params = "--o:ssl.termination=true"
        {% endif %}
        EOF
        destination = "local/snoop.env"
        env = true
      }

      template {
        data = <<EOF
{% include 'collabora-config.xml' %}
      EOF
        destination = "local/coolwsd.xml"
        perms = "555"
      }

      template {
      data = <<EOF
{% include 'collabora-entrypoint.sh' %}
      EOF
      destination = "local/collabora-entrypoint.sh"
      perms = "755"
      }

      resources {
        cpu = 500
        memory = 4096
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "collabora"
        port = "http"
        tags = ["fabio-:${config.port_collabora} proto=tcp"]
        check {
          initial_status = "critical"
          name = "tcp"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["collabora.${liquid_domain}"]
          }
      }
    }
  }
}
}
