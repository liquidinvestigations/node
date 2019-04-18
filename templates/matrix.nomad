job "matrix" {
  datacenters = ["dc1"]
  type = "service"

  group "synapse" {
    task "pg" {
      driver = "docker"
      config {
        image = "postgres:10"
        volumes = [
          "${liquid_volumes}/matrix/synapse/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "matrix-synapse-pg"
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
        network {
          port "pg" {}
        }
        memory = 500
      }
      service {
        name = "matrix-synapse-pg"
        port = "pg"
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
          liquid_task = "matrix-synapse"
        }
        port_map {
          synapse = 8008
        }
      }
      template {
        data  = <<EOF
          SYNAPSE_SERVER_NAME=synapse.{{ key "liquid_domain" }}
          SYNAPSE_REPORT_STATS=no
          SYNAPSE_ENABLE_REGISTRATION=no
          SYNAPSE_LOG_LEVEL=INFO
          SYNAPSE_NO_TLS=yes
          {{- range service "matrix-synapse-pg" }}
            POSTGRES_HOST={{ .Address }}
            POSTGRES_PORT={{ .Port }}
          {{- end }}
          POSTGRES_USER=synapse
          POSTGRES_PASSWORD=synapse
          POSTGRES_DB=synapse
        EOF
        destination = "local/synapse.env"
        env = true
      }
      resources {
        network {
          port "synapse" {}
        }
        memory = 500
      }
      service {
        name = "matrix-synapse"
        port = "synapse"
      }
    }

    task "riot" {
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
        data  = <<EOF
          -p 8765
          -A 0.0.0.0
          -c 3500
        EOF
        destination = "local/data/riot.im.conf"
      }
      template {
        data  = <<EOF
          {
            "default_hs_url": "http://synapse.{{ key "liquid_domain" }}",
            "default_is_url": "",
            "brand": "Liquid Riot",
            "integrations_ui_url": "",
            "integrations_rest_url": "",
            "bug_report_endpoint_url": "",
            "features": {
                "feature_groups": "labs",
                "feature_pinning": "labs"
            },
            "default_federate": false,
            "roomDirectory": null,
            "welcomeUserId": "@riot-bot:synapse.{{ key "liquid_domain" }}",
            "piwik": null
          }
        EOF
        destination = "local/data/config.json"
      }
      resources {
        network {
          port "riot" {}
        }
        memory = 500
      }
      service {
        name = "matrix-riot"
        port = "riot"
      }
    }
  }
}
