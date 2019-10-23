{% from '_lib.hcl' import authproxy_group, promtail_task with context -%}

job "dokuwiki" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  group "dokuwiki" {
    task "php" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config = {
        image = "${config.image('liquid-dokuwiki')}"
        force_pull = "true"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/dokuwiki/data:/bitnami",
        ]
        labels {
          liquid_task = "dokuwiki"
        }
        port_map {
          php = 80
        }
      }
      env {
        LIQUID_CORE_URL = "${config.liquid_core_url}"
        LIQUID_TITLE = "${config.liquid_title}"
        LIQUID_DOMAIN = "${config.liquid_domain}"
        LIQUID_HTTP_PROTOCOL = "${config.liquid_http_protocol}"
      }
      resources {
        memory = 500
        cpu = 90
        network {
          mbits = 1
          port "php" {}
        }
      }
      service {
        name = "dokuwiki-php"
        port = "php"
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["dokuwiki.${liquid_domain}"]
          }
        }
      }
    }

    ${ promtail_task() }
  }

  ${- authproxy_group(
      'dokuwiki',
      host='dokuwiki.' + liquid_domain,
      upstream='dokuwiki-php',
    ) }
}
