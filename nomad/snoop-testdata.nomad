job "snoop-testdata" {
  datacenters = ["dc1"]
  type = "service"

  group "snoop" {
    count = 1

    task "rabbitmq" {
      driver = "docker"
      config {
        image = "rabbitmq:3.7.3"
        port_map {
          amqp = 5672
        }
      }
      resources {
        network {
          port "amqp" {}
        }
      }
      service {
        name = "snoop-testdata-rabbitmq"
        port = "amqp"
      }
    }

    task "tika" {
      driver = "docker"
      config {
        image = "logicalspark/docker-tikaserver"
        port_map {
          http = 9998
        }
      }
      resources {
        network {
          port "tika" {}
        }
      }
      service {
        name = "snoop-testdata-tika"
        port = "tika"
      }
    }

    task "pg" {
      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "/var/local/liquid/volumes/snoop-testdata-pg/data:/var/lib/postgresql/data",
        ]
        port_map {
          pg = 5432
        }
      }
      env {
        POSTGRES_USER = "snoop"
        POSTGRES_DATABASE = "snoop"
      }
      resources {
        network {
          port "pg" {}
        }
      }
      service {
        name = "snoop-testdata-pg"
        port = "pg"
      }
    }

    task "api" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-snoop2:liquid-nomad"
        volumes = [
          "/var/local/liquid/volumes/gnupg:/opt/hoover/gnupg",
          "/var/local/liquid/volumes/testdata:/opt/hoover/snoop/collection",
          "/var/local/liquid/volumes/snoop-testdata-blobs/testdata:/opt/hoover/snoop/blobs",
          "/var/local/liquid/volumes/search-es-snapshots:/opt/hoover/es-snapshots",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "snoop-testdata-api"
        }
      }
      env {
        SECRET_KEY = "TODO random key"
        SNOOP_HTTP_HOSTNAME = "testdata.snoop"
      }
      template {
        data = <<EOF
            SNOOP_DB = postgresql://snoop:snoop@
              {{- range service "snoop-testdata-pg" -}}
                {{ .Address }}:{{ .Port }}
              {{- end -}}
              /snoop
          EOF
        destination = "local/snoop.env"
        env = true
      }
      resources {
        network {
          port "http" {}
        }
      }
      service {
        name = "core"
        tags = ["global", "app"]
        port = "http"
      }
    }
  }
}
