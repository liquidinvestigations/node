{% from '_lib.hcl' import shutdown_delay, task_logs, group_disk with context -%}

job "codimd" {
  datacenters = ["dc1"]
  type = "service"
  priority = 66

  group "codimd" {
    ${ group_disk() }
    task "codimd" {
      ${ task_logs() }

      # for the image uploads directory
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = -99
      }

      leader = true
      driver = "docker"
      config {
        image = "${config.image('codimd')}"
        port_map {
          http = 3000
        }
        labels {
          liquid_task = "codimd"
        }
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/codimd/image-uploads:/codimd/public/uploads",
          ${liquidinvestigations_codimd_server_repo}
        ]
        memory_hard_limit = 2000
      }
      resources {
        cpu = 100
        memory = 250
        network {
          mbits = 1
          port "http" {}
        }
      }
      env {
        NODE_ENV = "production"
        LIQUID_URL = "${config.liquid_http_protocol}://${liquid_domain}"
        LIQUID_TITLE = "${config.liquid_title}"
        CMD_HOST = "0.0.0.0"
        CMD_PORT = "3000"
        CMD_DOMAIN = "codimd.${liquid_domain}"
        CMD_URL_ADDPORT = "{% if config.https_enabled %}${ liquid_https_port }{% else %}${ liquid_http_port }{% endif %}"
        CMD_PROTOCOL_USESSL = "{% if config.https_enabled %}true{% else %}false{% endif %}"
        CMD_ALLOW_ORIGIN = "codimd.${liquid_domain}"
        CMD_USECDN = "false"
        CMD_EMAIL = "false"
        CMD_ALLOW_EMAIL_REGISTER = "false"
        CMD_ALLOW_ANONYMOUS = "false"
        CMD_ALLOW_ANONYMOUS_EDITS = "false"
        CMD_ALLOW_GRAVATAR = "false"
        CMD_ALLOW_FREEURL = "false"
      }
      template {
        data = <<-EOF
          {{- range service "codimd-pg" }}
            CMD_DB_URL = "postgresql://codimd:
            {{- with secret "liquid/codimd/codimd.postgres" -}}
              {{.Data.secret_key }}
            {{- end -}}
            @{{.Address}}:{{.Port}}/codimd"
          {{- end }}
        EOF
        destination = "local/codimd-pg.env"
        env = true
      }

      template {
        data = <<-EOF
        CMD_OAUTH2_BASEURL = "${config.liquid_core_url}"
        CMD_OAUTH2_AUTHORIZATION_URL = "${config.liquid_core_url}/o/authorize/"
        CMD_OAUTH2_USER_PROFILE_USERNAME_ATTR = "name"
        CMD_OAUTH2_USER_PROFILE_DISPLAY_NAME_ATTR = "name"
        CMD_OAUTH2_USER_PROFILE_EMAIL_ATTR = "email"

        {{- range service "core" }}
          CMD_OAUTH2_TOKEN_URL = "http://{{.Address}}:{{.Port}}/o/token/"
          CMD_OAUTH2_USER_PROFILE_URL = "http://{{.Address}}:{{.Port}}/accounts/profile"
        {{- end }}
        {{- with secret "liquid/codimd/app.auth.oauth2" }}
          CMD_OAUTH2_CLIENT_ID = {{.Data.client_id | toJSON }}
          CMD_OAUTH2_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
        {{- end }}
        CMD_OAUTH2_PROVIDERNAME = "Liquid"

        {{- with secret "liquid/codimd/codimd.session" }}
          CMD_SESSION_SECRET = {{.Data.secret_key | toJSON }}
        {{- end }}
        EOF

        destination = "local/codimd-auth.env"
        env = true
      }
      service {
        name = "codimd-app"
        port = "http"
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
        check_restart {
          limit = 3
          grace = "90s"
        }
      }
    }
  }
}
