job "hoover" {
  datacenters = ["dc1"]
  type = "service"

  group "deps" {
    task "es" {
      driver = "docker"
      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch-oss:6.2.4"
        args = ["/bin/sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data && echo chown done && /usr/local/bin/docker-entrypoint.sh"]
        volumes = [
          "${liquid_volumes}/hoover/es/data:/usr/share/elasticsearch/data",
        ]
        port_map {
          es = 9200
        }
        labels {
          liquid_task = "hoover-es"
        }
      }
      env {
        cluster.name = "hoover"
        ES_JAVA_OPTS = "-Xms1536m -Xmx1536m"
      }
      resources {
        memory = 2048
        network {
          port "es" {}
        }
      }
      service {
        name = "hoover-es"
        port = "es"
        check {
          name = "hoover-es alive on http"
          initial_status = "critical"
          type = "http"
          path = "/_cluster/health"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    task "pg" {
      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "${liquid_volumes}/hoover/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "hoover-pg"
        }
        port_map {
          pg = 5432
        }
      }
      env {
        POSTGRES_USER = "hoover"
        POSTGRES_DATABASE = "hoover"
      }
      resources {
        memory = 1024
        network {
          port "pg" {}
        }
      }
      service {
        name = "hoover-pg"
        port = "pg"
        check {
          name = "hoover-pg alive on tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "web" {
    task "search" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-search"
        volumes = [
          ${hoover_search_repo}
          "${liquid_volumes}/hoover-ui/build:/opt/hoover/ui/build",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "hoover-search"
        }
      }
      template {
        data = <<EOF
          {{- if keyExists "liquid_debug" }}
            DEBUG = {{key "liquid_debug"}}
          {{- end }}
          {{- with secret "liquid/hoover/search.django" }}
            SECRET_KEY = {{.Data.secret_key}}
          {{- end }}
          {{- range service "hoover-pg" }}
            HOOVER_DB = postgresql://hoover:hoover@{{.Address}}:{{.Port}}/hoover
          {{- end }}
          {{- range service "hoover-es" }}
            HOOVER_ES_URL = http://{{.Address}}:{{.Port}}
          {{- end }}
          HOOVER_HOSTNAME = hoover.{{key "liquid_domain"}}
          {{- with secret "liquid/hoover/search.oauth2" }}
            LIQUID_AUTH_PUBLIC_URL = http://{{key "liquid_domain"}}
            {{- range service "core" }}
              LIQUID_AUTH_INTERNAL_URL = http://{{.Address}}:{{.Port}}
            {{- end }}
            LIQUID_AUTH_CLIENT_ID = {{.Data.client_id}}
            LIQUID_AUTH_CLIENT_SECRET = {{.Data.client_secret}}
          {{- end }}
        EOF
        destination = "local/hoover.env"
        env = true
      }
      resources {
        memory = 512
        network {
          port "http" {}
        }
      }
      service {
        name = "hoover"
        port = "http"
        tags = [
          "traefik-ingress.frontend.rule=Host:hoover.${liquid_domain}",
        ]
        check {
          name = "hoover /_ping succeeds"
          initial_status = "critical"
          type = "http"
          path = "/_ping"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["hoover.${liquid_domain}"]
          }
        }
        check {
          name = "hoover alive on http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["hoover.${liquid_domain}"]
          }
        }
        check {
          name = "hoover healthcheck script"
          initial_status = "warning"
          type = "script"
          command = "python"
          args = ["manage.py", "healthcheck"]
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
  group "internal" {
    task "traefik" {
      driver = "docker"
      config {
        image = "traefik:1.7"
        port_map {
          http = 80
          admin = 8080
        }
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml:ro",
          "${consul_socket}:/consul.sock:ro",
        ]
      }
      template {
        data = <<-EOF
          debug = {{ key "liquid_debug" }}
          defaultEntryPoints = ["http"]

          [api]
          entryPoint = "admin"

          [entryPoints]
            [entryPoints.http]
            address = ":80"
            [entryPoints.admin]
            address = ":8080"

          [consulCatalog]
          endpoint = "unix:///consul.sock"
          prefix = "traefik-internal"

          [consul]
          endpoint = "unix:///consul.sock"
          prefix = "traefik-internal"
        EOF
        destination = "local/traefik.toml"
      }
      resources {
        network {
          port "http" {
            static = 8765
          }
          port "admin" {}
        }
      }
      service {
        name = "traefik-internal-http"
        port = "http"
      }
      service {
        name = "traefik-internal-admin"
        port = "admin"
        check {
          name = "traefik alive on http admin"
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
