job "nextcloud" {
  datacenters = ["dc1"]
  type = "service"
  
  group "nc" {
    task "nextcloud" {
      driver = "docker"
      config {
        image = "liquidinvestigations/liquid-nextcloud"
        volumes = [
          "${liquid_volumes}/nextcloud/nextcloud:/var/www/html",
          "${liquid_collections}/ncsync/data:/var/www/html/data/ncsync/files",
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
            NEXTCLOUD_POSTGRES_HOST =
              {{- range service "nextcloud-pg" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}  
            NEXTCLOUD_HOST = nextcloud.{{ key "liquid_domain" }}
            NEXTCLOUD_ADMIN_USER="admin"
            NEXTCLOUD_ADMIN_PASSWORD="admin"
            NEXTCLOUD_POSTGRES_DB="nextcloud"
            NEXTCLOUD_POSTGRES_USER="postgres"
            NEXTCLOUD_POSTGRES_PASSWORD="a_very_good_secret"
            OC_PASS="secret"
          EOF
        destination = "local/nextcloud.env"
        env = true
      }
      env {

      }
      resources {
        network {
          port "http" {}
        }
      }
      service {
        name = "nextcloud"
        port = "http"
      }
      }

    task "pg" {
      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "${liquid_volumes}/nextcloud/nextcloud-pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "nextcloud-pg"
        }
        port_map {
          pg = 5432
        }
        hostname = "nextcloud-pg"
      }
      env {
        POSTGRES_USER = "postgres"
        POSTGRES_PASSWORD = "secret"
      }
      resources {
        network {
          port "pg" {}
        }
      }
      service {
        name = "nextcloud-pg"
        port = "pg"
      }
    }
  }
}
