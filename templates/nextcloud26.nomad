{% from '_lib.hcl' import shutdown_delay, authproxy_group, group_disk, task_logs, continuous_reschedule, set_pg_password_template, set_pg_drop_template with context -%}
job "nextcloud26" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "nextcloud26" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "nextcloud26" {
      ${ task_logs() }
      driver = "docker"

      config {
        image = "${config.image('liquid-nextcloud26')}"
        args = ["/bin/bash", "/local/nextcloud26-entrypoint.sh", "/entrypoint.sh"]
        port_map {
          nextcloud26 = 80
        }
        labels {
          liquid_task = "nextcloud26"
        }
        memory_hard_limit = 4000
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud26/nextcloud/data:/var/www/html",
        ]
      }

      env {
          MYSQL_DATABASE = "nextcloud26"
          MYSQL_USER = "nextcloud26"
          NEXTCLOUD_UPDATE=1
          OBJECTSTORE_S3_BUCKET = "nextcloud26"
          OBJECTSTORE_S3_PORT = "${config.port_nextcloud26_minio}"
          OBJECTSTORE_S3_SSL = "false"
          OBJECTSTORE_S3_REGION = "optional"
          OBJECTSTORE_S3_USEPATH_STYLE = "true"
          OBJECTSTORE_S3_AUTOCREATE = "true"
          OVERWRITEPROTOCOL = "${config.liquid_http_protocol}"
      }

      template {
        data = <<-EOF
        NEXTCLOUD_TRUSTED_DOMAINS = "{{ env "attr.unique.network.ip-address" }} nextcloud26.${config.liquid_domain}"
        MYSQL_HOST = "{{ env "attr.unique.network.ip-address" }}:${config.port_nextcloud26_maria}"
        {{- with secret "liquid/nextcloud26/nextcloud.maria" }}
          MYSQL_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        NEXTCLOUD_ADMIN_USER = "admin"
        {{- with secret "liquid/nextcloud26/nextcloud.admin" }}
          NEXTCLOUD_ADMIN_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        OBJECTSTORE_S3_HOST = "{{ env "attr.unique.network.ip-address" }}"
        {{- with secret "liquid/nextcloud26/minio.user" }}
            OBJECTSTORE_S3_KEY = {{.Data.secret_key | toJSON }}
        {{- end }}
        {{- with secret "liquid/nextcloud26/minio.password" }}
            OBJECTSTORE_S3_SECRET = {{.Data.secret_key | toJSON }}
        {{- end }}
        OAUTH2_GROUPS_CLAIM = "roles"
        OAUTH2_PROFILE_FIELDS = "name"
        OAUTH2_NAME_FIELD = "name"
        OAUTH2_ADMIN_GROUP = "admin"
        OAUTH2_PROVIDER_NAME = "liquid"
        OAUTH2_PROVIDER_TITLE = "Liquid"
        OAUTH2_BASE_URL = "${config.liquid_core_url}"
        OAUTH2_AUTHORIZE_URL = "${config.liquid_core_url}/o/authorize/"
        OAUTH2_TOKEN_URL = "http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/o/token/"
        OAUTH2_PROFILE_URL = "http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/accounts/profile"
        OAUTH2_LOGOUT_URL = "${config.liquid_core_url}/accounts/logout/?next=/"
        {{- with secret "liquid/nextcloud26/app.auth.oauth2" }}
            OAUTH2_CLIENT_ID = {{.Data.client_id | toJSON }}
            OAUTH2_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
        {{- end }}
        EOF
        destination = "local/nextcloud.env"
        env = true
      }

      template {
      data = <<EOF
{% include 'nextcloud26-entrypoint.sh' %}
      EOF
      destination = "local/nextcloud26-entrypoint.sh"
      perms = "755"
      }


      resources {
        memory = 400
        cpu = 100
        network {
          mbits = 1
          port "nextcloud26" {}
        }
      }

      service {
        name = "liquid-nextcloud26"
        port = "nextcloud26"
        tags = ["fabio-:${config.port_nextcloud26} proto=tcp"]
        check {
          initial_status = "critical"
          name = "http"
          path = "/status.php"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          type = "http"
          header {
            Host = ["nextcloud26.${liquid_domain}"]
          }
        }
      }
    }
  }
}