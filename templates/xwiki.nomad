{% from '_lib.hcl' import shutdown_delay, group_disk, task_logs, continuous_reschedule, set_pg_password_template, set_pg_drop_template with context -%}
job "xwiki" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "xwiki" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "xwiki" {
      ${ task_logs() }
      driver = "docker"

      config {
        image = "${config.image('xwiki')}"
        entrypoint = ["/bin/bash", "/local/xwiki-entrypoint.sh"]
        port_map {
          xwiki = 8080
        }
        labels {
          liquid_task = "xwiki"
        }
        memory_hard_limit = 8000
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/xwiki/data:/usr/local/xwiki",
        ]
      }

      env {
        DB_USER = "xwiki"
        XWIKI_CONFIGURATION = "false"
      }

      template {
        data = <<-EOF
        {{- with secret "liquid/xwiki/xwiki.postgres" }}
            DB_PASSWORD={{.Data.secret_key | toJSON }}
        {{- end }}
          XWIKI_DB_URL = "{{ env "attr.unique.network.ip-address" }}:${config.port_xwiki_pg}"
        {{- with secret "liquid/xwiki/app.auth.oauth2" }}
            OAUTH2_CLIENT_ID = {{.Data.client_id | toJSON }}
            OAUTH2_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
        {{- end }}
        {{- with secret "liquid/xwiki/xwiki.superadmin" }}
            SUPERADMIN_PASSWORD={{.Data.secret_key | toJSON }}
        {{- end }}
        XWIKI_DB = "postgresql://xwiki:
        {{- with secret "liquid/xwiki/xwiki.postgres" -}}
          {{.Data.secret_key }}
        {{- end -}}
        @{{env "attr.unique.network.ip-address" }}:${config.port_xwiki_pg}/xwiki"
        XWIKI_INIT_CHECK_TABLE = "xwikidoc"
        OAUTH2_GROUPS_CLAIM = "roles"
        OAUTH2_PROFILE_FIELDS = "name"
        OAUTH2_NAME_FIELD = "name"
        OAUTH2_ADMIN_GROUP = "admin"
        OAUTH2_PROVIDER_NAME = "liquid"
        OAUTH2_PROVIDER_TITLE = "Liquid"
        LIQUID_URL = "${config.liquid_http_protocol}://{{ key "liquid_domain" }}"
        OAUTH2_BASE_URL = "${config.liquid_core_url}"
        OAUTH2_AUTHORIZE_URL = "${config.liquid_core_url}/o/authorize/"
        OAUTH2_TOKEN_URL = "http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/o/token/"
        OAUTH2_PROFILE_URL = "http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/accounts/profile"
        OAUTH2_LOGOUT_URL = "${config.liquid_core_url}/accounts/logout/?next=/"
        EOF
        destination = "local/xwiki.env"
        env = true
      }

      template {
        data = <<EOF
{% include 'xwiki-entrypoint.sh' %}
      EOF
        destination = "local/xwiki-entrypoint.sh"
        perms = "755"
      }


      resources {
        memory = 400
        cpu = 100
        network {
          mbits = 1
          port "xwiki" {}
        }
      }


      service {
        name = "liquid-xwiki"
        port = "xwiki"
        tags = [
          "fabio-:${config.port_xwiki} proto=tcp"
        ]
        check {
          initial_status = "critical"
          name = "tcp"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["xwiki.${liquid_domain}"]
          }
        }
      }
    }
  }
}
