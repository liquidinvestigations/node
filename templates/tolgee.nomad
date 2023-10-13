{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "tolgee" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  group "tolgee" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "tolgee" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }
      driver = "docker"
      config {
        image = "${config.image('tolgee')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/tolgee4:/data",
        ]
        port_map {
          http = 8080
          db = 25432
        }
        labels {
          liquid_task = "tolgee"
        }
        memory_hard_limit = 2000
      }

      env {
        TOLGEE_TELEMETRY_ENABLED=false
        TOLGEE_AUTHENTICATION_CREATE_INITIAL_USER=true
        TOLGEE_AUTHENTICATION_ENABLED=true
        TOLGEE_AUTHENTICATION_INITIAL_USERNAME="liquid-tolgee-admin@admin.com"
        TOLGEE_AUTHENTICATION_JWT_EXPIRATION=6048000000
        TOLGEE_AUTHENTICATION_JWT_SUPER_EXPIRATION=6048000000

        TOLGEE_AUTHENTICATION_NATIVE_ENABLED=true
        TOLGEE_AUTHENTICATION_USER_CAN_CREATE_ORGANIZATIONS=true

        TOLGEE_FRONT_END_URL = "${config.liquid_http_protocol}://tolgee.${config.liquid_domain}"

        TOLGEE_RATE_LIMITS_ENABLED=true
        TOLGEE_AUTHENTICATION_NEEDS_EMAIL_VERIFICATION=false
        TOLGEE_AUTHENTICATION_REGISTRATIONS_ALLOWED=false

        # TODO
        # TOLGEE_AUTHENTICATION_OAUTH2_AUTHORIZATION_URL=
        # TOLGEE_AUTHENTICATION_OAUTH2_CLIENT_ID=
        # TOLGEE_AUTHENTICATION_OAUTH2_CLIENT_SECRET=
        # TOLGEE_AUTHENTICATION_OAUTH2_SCOPES=[]
        # TOLGEE_AUTHENTICATION_OAUTH2_TOKEN_URL=
        # TOLGEE_AUTHENTICATION_OAUTH2_USER_URL=
      }

      template {
        data = <<-EOF

        {{- with secret "liquid/tolgee/jwt.secret" }}
          TOLGEE_AUTHENTICATION_JWT_SECRET = "{{.Data.secret_key }}"
        {{- end }}

        {{- with secret "liquid/tolgee/admin.password" }}
          TOLGEE_AUTHENTICATION_INITIAL_PASSWORD = "{{.Data.secret_key }}"
        {{- end }}

        {% if config.tolgee_github_enabled %}
          {{- with secret "liquid/tolgee/oauth.github" }}
            TOLGEE_AUTHENTICATION_GITHUB_CLIENT_ID = {{.Data.client_id | toJSON }}
            TOLGEE_AUTHENTICATION_GITHUB_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
          {{- end }}
        {% endif %}

        {% if config.tolgee_deepl_enabled %}
          {{- with secret "liquid/tolgee/mt.services" }}
            TOLGEE_MACHINE_TRANSLATION_DEEPL_AUTH_KEY="{{.Data.deepl_auth_key }}"
          {{- end }}
          TOLGEE_MACHINE_TRANSLATION_DEEPL_FORMALITY=default
          TOLGEE_MACHINE_TRANSLATION_DEEPL_DEFAULT_ENABLED=true
          TOLGEE_MACHINE_TRANSLATION_DEEPL_DEFAULT_PRIMARY=true
        {% endif %}

        {% if config.tolgee_google_enabled %}
          {{- with secret "liquid/tolgee/mt.services" }}
            TOLGEE_MACHINE_TRANSLATION_GOOGLE_API_KEY="{{.Data.google_api_key }}"
          {{- end }}
          TOLGEE_MACHINE_TRANSLATION_GOOGLE_DEFAULT_ENABLED=true
          TOLGEE_MACHINE_TRANSLATION_GOOGLE_DEFAULT_PRIMARY=false
        {% endif %}

        EOF
        destination = "local/tolgee.env"
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
        name = "tolgee"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:tolgee.${liquid_domain}",
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
}
