job "liquid" {
  datacenters = ["dc1"]
  type = "service"

  group "core" {
    task "core" {
      driver = "docker"
      config {
        image = "liquidinvestigations/core"
        volumes = [
          ${liquidinvestigations_core_repo}
          "${liquid_volumes}/liquid/core/var:/app/var",
        ]
        labels {
          liquid_task = "liquid-core"
        }
        port_map {
          http = 8000
        }
      }
      template {
        data = <<EOF
          DEBUG = {{key "liquid_debug"}}
          HTTP_HOST = {{key "liquid_domain"}}
          {{- with secret "liquid/liquid/core.django" }}
            SECRET_KEY = {{.Data.secret_key}}
          {{- end }}
        EOF
        destination = "local/docker.env"
        env = true
      }
      resources {
        memory = 200
        network {
          port "http" {}
        }
      }
      service {
        name = "core"
        port = "http"
        tags = [
          "traefik-ingress.frontend.rule=Host:${liquid_domain}",
        ]
        check {
          name = "liquid-core alive on http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "traefik-ingress" {
    task "traefik-ingress" {
      driver = "docker"
      config {
        image = "traefik:1.7"
        port_map {
          http = 80
          api = 8080
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
          entryPoint = "api"

          [entryPoints]
            [entryPoints.http]
            address = ":80"
            [entryPoints.api]
            address = ":8080"

          [consulCatalog]
          endpoint = "unix:///consul.sock"
          prefix = "traefik-ingress"

          [frontends]
            [frontends.frontend-consul]

          [consul]
          endpoint = "unix:///consul.sock"
          prefix = "traefik-ingress"
        EOF
        destination = "local/traefik.toml"
      }
      resources {
        network {
          port "http" {
            static = ${liquid_http_port}
          }
          port "api" {}
        }
      }
      service {
        name = "trafik-ingress-http"
        port = "http"
        check {
          name = "traefik alive on home page"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["${liquid_domain}"]
          }
        }
      }
      service {
        name = "trafik-ingress-webui"
        port = "api"
        check {
          name = "traefik alive on http webui"
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
