{% from '_lib.hcl' import authproxy_group with context -%}

job "nextcloud" {
  datacenters = ["dc1"]
  type = "service"
  priority = 45

  group "nc" {
    task "nextcloud" {
      driver = "docker"
      config {
        image = "liquidinvestigations/liquid-nextcloud"
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
      template {
        data = <<EOF
            {{- range service "nextcloud-pg" }}
              POSTGRES_HOST = {{.Address}}:{{.Port}}
            {{- end }}
            NEXTCLOUD_HOST = nextcloud.{{ key "liquid_domain" }}
            NEXTCLOUD_ADMIN_USER = admin
            NEXTCLOUD_ADMIN_PASSWORD = admin
            POSTGRES_DB = nextcloud
            POSTGRES_USER = postgres
            {{- with secret "liquid/nextcloud/nextcloud.pg" }}
              POSTGRES_PASSWORD = {{.Data.secret_key}}
            {{- end }}
            {{- with secret "liquid/nextcloud/nextcloud.admin" }}
              OC_PASS = {{.Data.secret_key}}
            {{- end }}
          EOF
        destination = "local/nextcloud.env"
        env = true
      }
      resources {
        network {
          port "http" {}
        }
      }
      service {
        name = "nextcloud-app"
        port = "http"
        check {
          name = "nextcloud alive on http"
          initial_status = "critical"
          type = "http"
          path = "/"
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
    task "pg" {
      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "${liquid_volumes}/nextcloud/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "nextcloud-pg"
        }
        port_map {
          pg = 5432
        }
      }
      template {
        data = <<EOF
          POSTGRES_USER ="postgres"
          {{- with secret "liquid/nextcloud/nextcloud.pg" }}
            POSTGRES_PASSWORD = {{.Data.secret_key}}
          {{- end }}
        EOF
        destination = "local/pg.env"
        env = true
      }
      resources {
        network {
          port "pg" {
            static = 8767
          }
        }
      }
      service {
        name = "nextcloud-pg"
        port = "pg"
        check {
          name = "postgres alive on tcp"
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
