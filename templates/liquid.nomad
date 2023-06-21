{% from '_lib.hcl' import continuous_reschedule, group_disk, task_logs -%}

job "liquid" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  group "core" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "core" {
      ${ task_logs() }

      # Constraint required for user sync
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "${config.image('liquid-core')}"
        volumes = [
          ${liquidinvestigations_core_repo}
          "{% raw %}${meta.liquid_volumes}{% endraw %}/liquid/core/var:/app/var",
        ]
        labels {
          liquid_task = "liquid-core"
        }
        port_map {
          http = 8000
        }

        memory_hard_limit = 2048
      }
      # used to auto-restart containers when running deploy, after you make a new commit
      env { __GIT_TAGS = "${liquidinvestigations_core_git}" }

      template {
        data = <<-EOF
          LIQUID_HEALTHCHECK_INFO_FILE = "/local/healthcheck_info.json"
          DEBUG = {{key "liquid_debug" | toJSON }}
          {{- with secret "liquid/liquid/core.django" }}
            SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          LIQUID_HTTP_PROTOCOL = "${config.liquid_http_protocol}"
          LIQUID_DOMAIN = "{{key "liquid_domain"}}"
          LIQUID_TITLE = "${config.liquid_title}"
          LIQUID_VERSION = "${config.liquid_version}"
          LIQUID_CORE_VERSION = "${config.liquid_core_version}"
          AUTH_STAFF_ONLY = "${config.auth_staff_only}"
          AUTH_AUTO_LOGOUT = "${config.auth_auto_logout}"
          LIQUID_2FA = "${config.liquid_2fa}"
          LIQUID_APPS = ${ config.liquid_apps | tojson | tojson}
          NOMAD_URL = "${config.nomad_url}"
          CONSUL_URL = "${config.consul_url}"
          AUTHPROXY_REDIS_URL = "redis://{{ env "attr.unique.network.ip-address" }}:${config.port_authproxy_redis}/"

          UPTRACE_DSN = "http://liquid-core-django@{{ env "attr.unique.network.ip-address" }}:${config.port_uptrace_native}/3"

          {% if config.enable_superuser_dashboards %}
          LIQUID_ENABLE_DASHBOARDS = "true"
          LIQUID_DASHBOARDS_PROXY_BASE_URL = "http://{{env "attr.unique.network.ip-address"}}:${config.port_lb}"
          LIQUID_DASHBOARDS_PROXY_NOMAD_URL = "http://{{env "attr.unique.network.ip-address"}}:4646"
          LIQUID_DASHBOARDS_PROXY_CONSUL_URL = "http://{{env "attr.unique.network.ip-address"}}:8500"
          {% endif %}
        EOF
        destination = "local/docker.env"
        env = true
      }

      template {
        data = <<-EOF
          #!/usr/bin/env python3
          import sys, os
          os.environ['DJANGO_SETTINGS_MODULE'] = 'liquidcore.site.settings'
          sys.path.append('/app')
          import django
          django.setup()
          from django.contrib.auth.models import User
          for u in User.objects.all():
              print(u.username)
          EOF
          perms = "755"
          destination = "local/users.py"
      }

      template {
        data = <<-EOF
${config.liquid_core_healthcheck_info}
          EOF
          destination = "local/healthcheck_info.json"
      }

      resources {
        memory = 200
        network {
          mbits = 1
          port "http" {
            static = 8768
          }
        }
      }

      service {
        name = "core"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:${liquid_domain}",
          "fabio-/_core strip=/_core",
        ]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["${liquid_domain}"]
          }
        }
      }

    }
  }
}
