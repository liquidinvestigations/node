{% from '_lib.hcl' import shutdown_delay, authproxy_group, group_disk, task_logs, continuous_reschedule, set_pg_password_template, set_pg_drop_template with context -%}
job "nextcloud27" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "nextcloud27" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "nextcloud27" {
      ${ task_logs() }
      driver = "docker"

      config {
        image = "${config.image('liquid-nextcloud27')}"
        entrypoint = ["/bin/bash", "/local/nextcloud27-entrypoint.sh"]
        port_map {
          nextcloud27 = 80
        }
        labels {
          liquid_task = "nextcloud27"
        }
        extra_hosts = ["nextcloud27.${config.liquid_domain}:127.0.0.1"]
        memory_hard_limit = 4000
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud27/nextcloud/data:/var/www/html",
        ]
      }

      env {
          MYSQL_DATABASE = "nextcloud27"
          MYSQL_USER = "nextcloud27"
          NEXTCLOUD_UPDATE=1
          OBJECTSTORE_S3_BUCKET = "nextcloud27"
          OBJECTSTORE_S3_PORT = "${config.port_nextcloud27_minio}"
          OBJECTSTORE_S3_SSL = "false"
          OBJECTSTORE_S3_REGION = "optional"
          OBJECTSTORE_S3_USEPATH_STYLE = "true"
          OBJECTSTORE_S3_AUTOCREATE = "true"
          OVERWRITEPROTOCOL = "${config.liquid_http_protocol}"
      }

      template {
        data = <<-EOF
        HTTP_PROTO = "${config.liquid_http_protocol}"
        NEXTCLOUD_HOST = "nextcloud27.{{ key "liquid_domain" }}"
        NEXTCLOUD_TRUSTED_DOMAINS = "{{ env "attr.unique.network.ip-address" }} nextcloud27.${config.liquid_domain}"
        MYSQL_HOST = "{{ env "attr.unique.network.ip-address" }}:${config.port_nextcloud27_maria}"
        {{- with secret "liquid/nextcloud27/nextcloud.maria" }}
          MYSQL_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        NEXTCLOUD_ADMIN_USER = "admin"
        {{- with secret "liquid/nextcloud27/nextcloud.admin" }}
          NEXTCLOUD_ADMIN_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        OBJECTSTORE_S3_HOST = "{{ env "attr.unique.network.ip-address" }}"
        {{- with secret "liquid/nextcloud27/minio.user" }}
            OBJECTSTORE_S3_KEY = {{.Data.secret_key | toJSON }}
        {{- end }}
        {{- with secret "liquid/nextcloud27/minio.password" }}
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
        {{- with secret "liquid/nextcloud27/app.auth.oauth2" }}
            OAUTH2_CLIENT_ID = {{.Data.client_id | toJSON }}
            OAUTH2_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
        {{- end }}
        EOF
        destination = "local/nextcloud.env"
        env = true
      }

      template {
      data = <<EOF
{% include 'nextcloud27-entrypoint.sh' %}
      EOF
      destination = "local/nextcloud27-entrypoint.sh"
      perms = "755"
      }


      resources {
        memory = 400
        cpu = 100
        network {
          mbits = 1
          port "nextcloud27" {}
        }
      }

      service {
        name = "liquid-nextcloud27"
        port = "nextcloud27"
        tags = ["fabio-:${config.port_nextcloud27} proto=tcp"]
        check {
          initial_status = "critical"
          name = "http"
          path = "/status.php"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          type = "http"
          header {
            Host = ["nextcloud27.${liquid_domain}"]
          }
        }
      }
    }
  }
}
