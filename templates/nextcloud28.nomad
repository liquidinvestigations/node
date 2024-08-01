{% from '_lib.hcl' import shutdown_delay, authproxy_group, group_disk, task_logs, continuous_reschedule, set_pg_password_template, set_pg_drop_template with context -%}
job "nextcloud28" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "nextcloud28" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "nextcloud28" {
      ${ task_logs() }
      driver = "docker"

      config {
        image = "${config.image('liquid-nextcloud28')}"
        entrypoint = ["/bin/bash", "/local/nextcloud28-entrypoint.sh"]
        port_map {
          nextcloud28 = 80
        }
        labels {
          liquid_task = "nextcloud28"
        }
        extra_hosts = [
          "nextcloud28.${config.liquid_domain}:127.0.0.1"
        ]
        memory_hard_limit = 4000
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud28/nextcloud/data:/var/www/html",
        ]
      }

      env {
          MYSQL_DATABASE = "nextcloud28"
          MYSQL_USER = "nextcloud28"
          NEXTCLOUD_UPDATE=1
          OBJECTSTORE_S3_BUCKET = "nextcloud28"
          OBJECTSTORE_S3_PORT = "${config.port_nextcloud28_minio}"
          OBJECTSTORE_S3_SSL = "false"
          OBJECTSTORE_S3_REGION = "optional"
          OBJECTSTORE_S3_USEPATH_STYLE = "true"
          OBJECTSTORE_S3_AUTOCREATE = "true"
          OVERWRITEPROTOCOL = "${config.liquid_http_protocol}"
      }

      template {
        data = <<-EOF
        LIQUID_BASE_IP = "{{ env "attr.unique.network.ip-address" }}"
        HTTP_PROTO = "${config.liquid_http_protocol}"
        NEXTCLOUD_HOST = "nextcloud28.{{ key "liquid_domain" }}"
        COLLABORA_HOST = "collabora.{{ key "liquid_domain" }}"
        COLLABORA_URL = "${config.liquid_http_protocol}://collabora.{{ key "liquid_domain" }}"
        LIQUID_URL = "${config.liquid_http_protocol}://{{ key "liquid_domain" }}"
        LIQUID_HOST = "${config.liquid_domain}"
        LIQUID_TITLE = "${config.liquid_title}"
        NEXTCLOUD_IP = "http://{{ env "attr.unique.network.ip-address" }}:${config.port_nextcloud28}"
        COLLABORA_IP = "http://{{ env "attr.unique.network.ip-address" }}:${config.port_collabora}"
        NEXTCLOUD_TRUSTED_DOMAINS = "{{ env "attr.unique.network.ip-address" }} nextcloud28.${config.liquid_domain}"
        MYSQL_HOST = "{{ env "attr.unique.network.ip-address" }}:${config.port_nextcloud28_maria}"
        {{- with secret "liquid/nextcloud28/nextcloud.maria" }}
          MYSQL_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        NEXTCLOUD_ADMIN_USER = "admin"
        {{- with secret "liquid/nextcloud28/nextcloud.admin" }}
          NEXTCLOUD_ADMIN_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        OBJECTSTORE_S3_HOST = "{{ env "attr.unique.network.ip-address" }}"
        {{- with secret "liquid/nextcloud28/minio.user" }}
            OBJECTSTORE_S3_KEY = {{.Data.secret_key | toJSON }}
        {{- end }}
        {{- with secret "liquid/nextcloud28/minio.password" }}
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
        {{- with secret "liquid/nextcloud28/app.auth.oauth2" }}
            OAUTH2_CLIENT_ID = {{.Data.client_id | toJSON }}
            OAUTH2_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
        {{- end }}
        DEMO_MODE = "${config.hoover_demo_mode}"
        EOF
        destination = "local/nextcloud.env"
        env = true
      }

      template {
        data = <<EOF
{% include 'nextcloud28-entrypoint.sh' %}
      EOF
        destination = "local/nextcloud28-entrypoint.sh"
        perms = "755"
      }


      resources {
        memory = 400
        cpu = 100
        network {
          mbits = 1
          port "nextcloud28" {}
        }
      }

      service {
        name = "liquid-nextcloud28"
        port = "nextcloud28"
        tags = ["fabio-:${config.port_nextcloud28} proto=tcp"]
        check {
          initial_status = "critical"
          name = "http"
          path = "/status.php"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          type = "http"
          header {
            Host = ["nextcloud28.${liquid_domain}"]
          }
        }
      }
    }
  }
}
