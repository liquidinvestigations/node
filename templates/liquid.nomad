{% from '_lib.hcl' import continuous_reschedule, group_disk, task_logs -%}

job "liquid" {
  datacenters = ["dc1"]
  type = "service"
  priority = 90

  group "core" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "core" {
      ${ task_logs() }
      # Constraint required for hypothesis-usersync
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      # user = 666
      config {
        image = "${config.image('liquid-core')}"
        # args = ["/bin/sleep", "1000"]
        volumes = [
          ${liquidinvestigations_core_repo}
          "{% raw %}${meta.liquid_volumes}{% endraw %}/liquid/core/var:/app/var",
        ]
        #mounts = [
        #{
        #  type = "volume"
        #  target = "/app/var"
        #  source = "{% raw %}${meta.liquid_volumes}{% endraw %}/liquid/core/var"
        #  # source = "test_core"
        #  readonly = false
        #}
        #]
        #mounts = [
        #{
        #  type = "bind"
        #  target = "/app/var"
        #  source = ${liquidinvestigations_core_repo}"{% raw %}${meta.liquid_volumes}{% endraw %}/liquid/core/var"
        #  readonly = false
        #  bind_options {
        #    propagation = "rshared"
        #  }
        #}
        #]
        labels {
          liquid_task = "liquid-core"
        }
        port_map {
          http = 8000
        }
      }
      template {
        data = <<-EOF
          DEBUG = {{key "liquid_debug" | toJSON }}
          {{- with secret "liquid/liquid/core.django" }}
            SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          LIQUID_HTTP_PROTOCOL = "${config.liquid_http_protocol}"
          LIQUID_DOMAIN = "{{key "liquid_domain"}}"
          LIQUID_TITLE = "${config.liquid_title}"
          SERVICE_ADDRESS = "{{env "NOMAD_IP_http"}}"
          AUTH_STAFF_ONLY = "${config.auth_staff_only}"
          AUTH_AUTO_LOGOUT = "${config.auth_auto_logout}"
          LIQUID_2FA = "${config.liquid_2fa}"
          HOOVER_APP_URL = "${config.liquid_http_protocol}://hoover.${config.liquid_domain}"
          DOKUWIKI_APP_URL = "${config.liquid_http_protocol}://dokuwiki.${config.liquid_domain}"
          ROCKETCHAT_APP_URL = "${config.liquid_http_protocol}://rocketchat.${config.liquid_domain}"
          NEXTCLOUD_APP_URL = "${config.liquid_http_protocol}://nextcloud.${config.liquid_domain}"
          CODIMD_APP_URL = "${config.liquid_http_protocol}://codimd.${config.liquid_domain}"
          HYPOTHESIS_APP_URL = "${config.liquid_http_protocol}://hypothesis.${config.liquid_domain}"
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
