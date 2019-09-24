{% from '_lib.hcl' import authproxy_group, promtail_task with context -%}

job "codimd" {
  datacenters = ["dc1"]
  type = "service"
  priority = 66

  group "codimd" {
    task "codimd" {
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
        TITLE = "${config.liquid_title}"
        CMD_HOST = "0.0.0.0"
        CMD_PORT = "3000"
        CMD_DOMAIN = "codimd.${liquid_domain}"
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
      }
    }

    ${ promtail_task() }
  }

  group "db" {
    task "postgres" {
      leader = true
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "postgres:11.5"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/codimd/postgres:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "codimd-pg"
        }
        port_map {
          pg = 5432
        }
      }
      template {
        data = <<-EOF
        POSTGRES_DB = "codimd"
        POSTGRES_USER = "codimd"
        {{- with secret "liquid/codimd/codimd.postgres" }}
          POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        EOF
        destination = "local/pg.env"
        env = true
      }
      resources {
        cpu = 100
        memory = 170
        network {
          mbits = 1
          port "pg" {}
        }
      }
      service {
        name = "codimd-pg"
        port = "pg"
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    ${ promtail_task() }
  }

  ${- authproxy_group(
      'codimd',
      host='codimd.' + liquid_domain,
      upstream='codimd-app',
      threads=100,
      memory=300,
    ) }
}
