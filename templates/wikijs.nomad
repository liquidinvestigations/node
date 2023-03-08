{% from '_lib.hcl' import shutdown_delay, group_disk, task_logs, continuous_reschedule, set_pg_password_template, set_pg_drop_template with context -%}
job "wikijs" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "wikijs" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "wikijs" {
      ${ task_logs() }
      driver = "docker"
      user = "root"

      config {
        image = "${config.image('wikijs')}"
        port_map {
          wikijs = 3000
        }
        entrypoint = ["/bin/bash"]
        args = ["/local/startup.sh"]
        labels {
          liquid_task = "wikijs"
        }
        memory_hard_limit = 2000
      }

      env {
        DB_TYPE = "postgres"
        DB_PORT = ${config.port_wikijs_pg}
        DB_USER = "wikijs"
        DB_NAME = "wikijs"
        NODE_ENV = "development"
        # DB_HOST = "10.66.60.1"
        # DB_PASS = "test"
      }

      template {
        data = <<-EOF
          {{- with secret "liquid/wikijs/wikijs.postgres" -}}
              DB_PASS={{.Data.secret_key | toJSON }}
          {{- end }}
          DB_HOST = {{env "attr.unique.network.ip-address" }}
          WIKIJS_DB = "postgresql://wikijs:
          {{- with secret "liquid/wikijs/wikijs.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{env "attr.unique.network.ip-address" }}:${config.port_wikijs_pg}/wikijs"

          WIKIJS_HOST_URL = "${config.liquid_http_protocol}://wikijs.${config.liquid_domain}"

          WIKIJS_OAUTH2_BASEURL = "${config.liquid_core_url}"
          WIKIJS_OAUTH2_AUTHORIZATION_URL = "${config.liquid_core_url}/o/authorize/"
          WIKIJS_OAUTH2_LOGOUT_URL = "${config.liquid_core_url}/accounts/logout/?next=/"
          WIKIJS_OAUTH2_USER_PROFILE_USERNAME_ATTR = "name"
          WIKIJS_OAUTH2_USER_PROFILE_ID_ATTR = "id"
          WIKIJS_OAUTH2_USER_PROFILE_DISPLAY_NAME_ATTR = "name"
          WIKIJS_OAUTH2_USER_PROFILE_EMAIL_ATTR = "email"
          WIKIJS_OAUTH2_USER_PROFILE_GROUPS_ATTR = "roles"

          WIKIJS_OAUTH2_TOKEN_URL = "http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/o/token/"
          WIKIJS_OAUTH2_USER_PROFILE_URL =  "http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/accounts/profile"
          {{- with secret "liquid/wikijs/app.auth.oauth2" }}
            WIKIJS_OAUTH2_CLIENT_ID = {{.Data.client_id | toJSON }}
              WIKIJS_OAUTH2_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
              {{- end }}
              WIKIJS_OAUTH2_PROVIDERNAME = "Liquid"
        EOF
        destination = "local/wikijs.env"
        env = true
      }

      template {
        left_delimiter = "DELIM_LEFT"
        right_delimiter = "DELIM_RIGHT"
        data = <<EOF
{% include 'wikijsdbdump.sql' %}
        EOF
        destination = "local/wikijsdbdump.sql"
      }

      template {
        data = <<EOF
        #!/bin/bash
        set -ex
        apk --update add postgresql-client gettext
        ls /local
        envsubst < /local/wikijsdbdump.sql | psql $WIKIJS_DB
        echo 'Ran database migration.'
        node server
        EOF
        env = false
        destination = "local/startup.sh"
      }

      resources {
        memory = 400
        cpu = 290
        network {
          mbits = 1
          port "wikijs" {}
        }
      }

      service {
        name = "liquid-wikijs"
        port = "wikijs"
        tags = [
          "fabio-:${config.port_wikijs} proto=tcp"
          # "traefik.enable=true",
          # "traefik.frontend.rule=Host:${'wikijs.' + liquid_domain}",
          # "fabio-:${config.port_wikijs} proto=tcp"
        ]
        check {
          initial_status = "critical"
          name = "http"
          path = "/healthz"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          type = "http"
          header {
            Host = ["wikijs.${liquid_domain}"]
          }
        }
      }
    }
  }
}