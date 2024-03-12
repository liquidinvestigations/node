{% from '_lib.hcl' import shutdown_delay, group_disk, task_logs, continuous_reschedule with context -%}

job "collabora" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "collabora" {
    ${ group_disk() }
    ${ continuous_reschedule() }
    network {
      port "http" {
        to = 9980
      }
    }

    task "collabora" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      ${ shutdown_delay() }
      config {
        image = "collabora/code:latest"
        entrypoint = ["/bin/bash", "/local/collabora-entrypoint.sh"]
        ports = [
          "http",
        ]
        labels {
          liquid_task = "collabora"
        }
        memory_hard_limit = 16384
      }


      env {
        server_name = "collabora.liquid.example.org"
        extra_params = "--o:ssl.enable=false --o:ssl.termination=false"
        #aliasgroup1 = "http://nextcloud28.liquid.example.org,http://10.66.60.1:22777"
        #aliasgroup2= "http://192.168.178.144:5555"
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
