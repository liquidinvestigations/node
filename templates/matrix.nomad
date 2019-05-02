job "matrix" {
  datacenters = ["dc1"]
  type = "service"

  group "homeserver" {
    task "pg" {
      driver = "docker"
      config {
        image = "postgres:10"
        volumes = [
          "${liquid_volumes}/matrix/synapse/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "matrix-homeserver-pg"
        }
        port_map {
          pg = 5432
        }
      }
      env {
        POSTGRES_USER = "synapse"
        POSTGRES_DATABASE = "synapse"
        POSTGRES_PASSWORD = "synapse"
      }
      resources {
        memory = 500
        cpu = 500
        network {
          port "pg" {}
        }
      }
      service {
        name = "matrix-homeserver-pg"
        port = "pg"
        check {
          name = "matrix-homeserver-pg"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    task "synapse" {
      driver = "docker"
      config = {
        image = "docker.io/matrixdotorg/synapse"
        volumes = [
          "${liquid_volumes}/matrix/synapse/synapse/data:/data"
        ]
        labels {
          liquid_task = "matrix-homeserver-synapse"
        }
        port_map {
          synapse = 8008
        }
      }
      template {
        data  = <<EOF
          SYNAPSE_SERVER_NAME=synapse.${liquid_domain}
          SYNAPSE_REPORT_STATS=no
          SYNAPSE_ENABLE_REGISTRATION=no
          SYNAPSE_LOG_LEVEL=INFO
          SYNAPSE_NO_TLS=yes
          {{- range service "matrix-homeserver-pg" }}
            POSTGRES_HOST={{.Address}}
            POSTGRES_PORT={{.Port}}
          {{- end }}
          POSTGRES_USER=synapse
          POSTGRES_PASSWORD=synapse
          POSTGRES_DB=synapse
        EOF
        destination = "local/synapse.env"
        env = true
      }
      resources {
        memory = 500
        cpu = 500
        network {
          port "synapse" {}
        }
      }
      service {
        name = "matrix-homeserver-synapse"
        port = "synapse"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:synapse.${liquid_domain}",
        ]
        check {
          name = "matrix-homeserver-synapse"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "riot" {
    task "web" {
      driver = "docker"
      config = {
        image = "avhost/docker-matrix-riot"
        volumes = [
          "local/data:/data",
        ]
        labels {
          liquid_task = "matrix-riot"
        }
        port_map {
          riot = 8765
        }
      }
      template {
        data = <<EOF
          -p 8765
          -A 0.0.0.0
          -c 3500
        EOF
        destination = "local/data/riot.im.conf"
      }
      template {
        data  = <<EOF
          {
            "default_hs_url": "http://synapse.${liquid_domain}",
            "default_is_url": "",
            "brand": "Liquid Riot",
            "integrations_ui_url": "",
            "integrations_rest_url": "",
            "bug_report_endpoint_url": "",
            "default_federate": false,
            "roomDirectory": null,
            "welcomeUserId": "@riot-bot:synapse.${liquid_domain}",
            "piwik": null
          }
        EOF
        destination = "local/data/config.json"
      }
      resources {
        memory = 100
        cpu = 100
        network {
          port "riot" {}
        }
      }
      service {
        name = "matrix-riot-web"
        port = "riot"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:riot.${liquid_domain}",
        ]
        check {
          name = "matrix-riot-web"
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
