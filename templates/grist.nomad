{% from '_lib.hcl' import shutdown_delay, task_logs, group_disk, continuous_reschedule with context -%}

job "grist" {
  datacenters = ["dc1"]
  type = "service"
  priority = 97

  group "grist" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "grist" {
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
        image = "${config.image('grist')}"
        port_map {
          http = 8484
        }
        labels {
          liquid_task = "grist"
        }
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/grist/persist:/persist",
        ]
        memory_hard_limit = 19999
        # extra_hosts = ["liquid.example.org:10.66.60.1"]   # not using oidc
      }

      resources {
        cpu = 300
        memory = 250
        network {
          mbits = 1
          port "http" {}
        }
      }
      env {

        GRIST_SUPPORT_ANON= false
        GRIST_SANDBOX_FLAVOR = "gvisor"
        # GRIST_SANDBOX_FLAVOR = "unsandboxed"

        APP_HOME_URL ="${config.liquid_http_protocol}://grist.${liquid_domain}"
        APP_DOC_URL ="${config.liquid_http_protocol}://grist.${liquid_domain}"
        APP_HOME_INTERNAL_URL="http://localhost:8484"
        APP_DOC_INTERNAL_URL="http://localhost:8484"


        # https://github.com/gristlabs/grist-core/issues/733#issuecomment-1822223083
        GRIST_SINGLE_ORG = "liquid"
        # GRIST_SINGLE_ORG = "docs"

        GRIST_ORG_IN_PATH="true"

        COOKIE_MAX_AGE = "864000000"  # 10 days in ms
        GRIST_FORCE_LOGIN = "true"
        GRIST_ANON_PLAYGROUND="false"
        GRIST_HIDE_UI_ELEMENTS= "helpCenter,billing,templates,multiSite,multiAccounts"
        GRIST_DEFAULT_EMAIL="${config.grist_initial_admin}"
        GRIST_SUPPORT_EMAIL="${config.grist_initial_admin}"
        # GRIST_SNAPSHOT_TIME_CAP = '{"hour": 12, "day": 8, "isoWeek": 4, "month": 12, "year": 1}'
        GRIST_DOMAIN = "grist.${liquid_domain}"

        GRIST_PAGE_TITLE_SUFFIX= "-- ${config.liquid_title}"
        GRIST_IGNORE_SESSION = "true"

        GRIST_FORWARD_AUTH_HEADER = "X-Forwarded-Email"
        # GRIST_FORWARD_AUTH_HEADER = "X-Forwarded-User"
        GRIST_FORWARD_AUTH_LOGIN_PATH = "/oauth2/sign_in"
        GRIST_FORWARD_AUTH_LOGOUT_PATH = "/oauth2/sign_out"

        LOGOUT_REDIRECT = "${config.liquid_http_protocol}://${liquid_domain}"

        GRIST_TELEMETRY_LEVEL="off"


      }

      template {
        data = <<-EOF
        {{- with secret "liquid/grist/session.secret" }}
          GRIST_SESSION_SECRET = {{.Data.secret_key | toJSON }}
        {{- end }}

        REDIS_URL = "redis://{{ env "attr.unique.network.ip-address" }}:${config.port_grist_redis}"

        TYPEORM_DATABASE  = "grist"
        TYPEORM_HOST  = "{{ env "attr.unique.network.ip-address" }}"
        {{- with secret "liquid/grist/grist.postgres" }}
          TYPEORM_PASSWORD  = {{.Data.secret_key | toJSON }}
        {{- end }}
        TYPEORM_PORT = ${config.port_grist_pg}
        TYPEORM_TYPE = "postgres"
        TYPEORM_USERNAME = "grist"


        {{- with secret "liquid/grist/minio.user" }}
            GRIST_DOCS_MINIO_ACCESS_KEY = {{.Data.secret_key | toJSON }}
        {{- end }}
        {{- with secret "liquid/grist/minio.password" }}
            GRIST_DOCS_MINIO_SECRET_KEY = {{.Data.secret_key | toJSON }}
        {{- end }}
        GRIST_DOCS_MINIO_USE_SSL=0
        GRIST_DOCS_MINIO_BUCKET=grist-docs
        GRIST_DOCS_MINIO_ENDPOINT={{ env "attr.unique.network.ip-address" }}
        GRIST_DOCS_MINIO_PORT = ${config.port_grist_s3}

        EOF

        destination = "local/grist-auth.env"
        env = true
      }

      service {
        name = "grist-web"
        port = "http"
        tags = ["fabio-:${config.port_grist_web} proto=tcp"]
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
        check_restart {
          limit = 5
          grace = "990s"
        }
      }
    }
  }
}
