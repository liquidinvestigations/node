{% from '_lib.hcl' import shutdown_delay, authproxy_group, group_disk, task_logs, continuous_reschedule, set_pg_password_template, set_pg_drop_template with context -%}
job "nextcloud" {
  datacenters = ["dc1"]
  type = "service"
  priority = 97

  group "nextcloud" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "nextcloud" {
      ${ task_logs() }
      driver = "docker"

      config {
        image = "${config.image('liquid-nextcloud')}"
        port_map {
          nextcloud = 80
        }
        labels {
          liquid_task = "nextcloud"
        }
        memory_hard_limit = ${1500 + 3 * config.nextcloud_memory_limit}
      }
      resources {
        cpu = 200
        memory = ${config.nextcloud_memory_limit}
        network {
          mbits = 1
          port "http" {}
        }
      }

      env {
          MYSQL_DATABASE = "nextcloud"
          MYSQL_USER = "nextcloud"
          NEXTCLOUD_TRUSTED_DOMAINS = "10.66.60.1 nextcloud.liquid.example.org"
          OBJECTSTORE_S3_BUCKET = "nextcloud"
          OBJECTSTORE_S3_PORT = "${config.port_nextcloud_minio}"
          OBJECTSTORE_S3_SSL = "false"
          OBJECTSTORE_S3_REGION = "optional"
          OBJECTSTORE_S3_USEPATH_STYLE = "true"
          OBJECTSTORE_S3_AUTOCREATE = "true"
      }

      template {
        data = <<-EOF
        MYSQL_HOST = "{{ env "attr.unique.network.ip-address" }}:${config.port_nextcloud_maria}"
        {{- with secret "liquid/nextcloud/nextcloud.maria" }}
          MYSQL_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        NEXTCLOUD_ADMIN_USER = "admin"
        {{- with secret "liquid/nextcloud/nextcloud.admin" }}
          NEXTCLOUD_ADMIN_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        OBJECTSTORE_S3_HOST = "{{ env "attr.unique.network.ip-address" }}"
        {{- with secret "liquid/nextcloud/minio.user" }}
            OBJECTSTORE_S3_KEY = {{.Data.secret_key | toJSON }}
        {{- end }}
        {{- with secret "liquid/nextcloud/minio.password" }}
            OBJECTSTORE_S3_SECRET = {{.Data.secret_key | toJSON }}
        {{- end }}
        EOF
        destination = "local/nextcloud.env"
        env = true
      }


      resources {
        memory = 400
        cpu = 100
        network {
          mbits = 1
          port "nextcloud" {}
        }
      }

      service {
        name = "liquid-nextcloud"
        port = "nextcloud"
        tags = ["fabio-:${config.port_nextcloud} proto=tcp"]
        check {
          initial_status = "critical"
          name = "http"
          path = "/status.php"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          type = "http"
          header {
            Host = ["nextcloud.${liquid_domain}"]
          }
        }
      }
    }
  }
}