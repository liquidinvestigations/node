{% from '_lib.hcl' import authproxy_group with context -%}

job "nextcloud" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  group "nc" {
    task "nextcloud" {
      driver = "docker"
      config {
        image = "${config.image('liquid-nextcloud')}"
        volumes = [
          "${liquid_volumes}/nextcloud/nextcloud:/var/www/html",
          "${liquid_collections}/uploads/data:/var/www/html/data/uploads/files",
        ]
        args = ["/bin/sh", "-c", "chown -R 33:33 /var/www/html/ && echo chown done && /entrypoint.sh apache2-foreground"]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "nextcloud"
        }
      }
      resources {
        cpu = 100
        memory = 150
        network {
          mbits = 1
          port "http" {}
        }
      }
      env {
        NEXTCLOUD_URL = "${config.liquid_http_protocol}://nextcloud.${config.liquid_domain}"
        LIQUID_TITLE = "${config.liquid_title}"
        LIQUID_CORE_URL = "${config.liquid_core_url}"
      }
      template {
        data = <<-EOF
        {{- with secret "liquid/nextcloud/nextcloud.uploads" }}
          UPLOADS_USER_PASS = {{.Data.secret_key | toJSON }}
        {{- end }}
        NEXTCLOUD_ADMIN = "admin"
        {{- with secret "liquid/nextcloud/nextcloud.admin" }}
          NEXTCLOUD_ADMIN_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        EOF
        destination = "local/nextcloud-migrate.env"
        env = true
      }
      service {
        name = "nextcloud-app"
        port = "http"
        check {
          name = "nextcloud alive on http"
          initial_status = "critical"
          type = "http"
          path = "/status.php"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["nextcloud.${liquid_domain}"]
          }
        }
      }
    }
  }

  group "db" {
    task "maria" {
      driver = "docker"
      config {
        image = "mariadb:10.4"
        volumes = [
          "${liquid_volumes}/nextcloud/mysql:/var/lib/mysql",
        ]
        labels {
          liquid_task = "nextcloud-maria"
        }
        port_map {
          maria = 3306
        }
      }
      template {
        data = <<-EOF
        MYSQL_RANDOM_ROOT_PASSWORD = "yes"
        MYSQL_DATABASE = "nextcloud"
        MYSQL_USER = "nextcloud"
        {{- with secret "liquid/nextcloud/nextcloud.maria" }}
          MYSQL_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        EOF
        destination = "local/maria.env"
        env = true
      }
      resources {
        cpu = 100
        memory = 250
        network {
          mbits = 1
          port "maria" {
            static = 8767
          }
        }
      }
      service {
        name = "nextcloud-maria"
        port = "maria"
        check {
          name = "mariadb alive on tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  ${- authproxy_group(
      'nextcloud',
      host='nextcloud.' + liquid_domain,
      upstream='nextcloud-app',
    ) }

}
