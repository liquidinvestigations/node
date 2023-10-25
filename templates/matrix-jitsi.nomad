

group "jitsi-web" {
  ${ group_disk() }
  ${ continuous_reschedule() }

  task "jitsi-web" {
    constraint {
      attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
      operator = "is_set"
    }

    ${ task_logs() }
    driver = "docker"
    config {
      image = "${config.image('jitsi-web')}"
      volumes = [
        "{% raw %}${meta.liquid_volumes}{% endraw %}/matrix/jitsi:/data",
      ]
      port_map {
        http = 80
      }
      labels {
        liquid_task = "matrix_jitsi"
      }
      memory_hard_limit = 2000
    }

    env {
      matrix_GITHUB_SERVER = "https://github.com"
    }

    template {
      data = <<-EOF

      matrix_SECRET_SKIP_VERIFY = "true"

      EOF
      destination = "local/matrix.env"
      env = true
    }

    resources {
      memory = 450
      cpu = 150
      network {
        mbits = 1
        port "http" {}
      }
    }

    service {
      name = "matrix-jitsi"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.frontend.rule=Host:jitsi.${liquid_domain}",
        "fabio-:${config.port_matrix_jitsi} proto=tcp",
      ]
      check {
        name = "http"
        initial_status = "critical"
        type = "http"
        path = "/"
        interval = "${check_interval}"
        timeout = "${check_timeout}"
      }
    }
  }
}
