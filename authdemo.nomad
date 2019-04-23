job "authdemo" {
  datacenters = ["dc1"]
  type = "service"

  group "demo" {
    task "app" {
      driver = "docker"
      config {
        image = "liquidinvestigations/authproxy"
        args = ["./testapp.py"]
        labels {
          liquid_task = "authdemo-app"
        }
        port_map {
          http = 5000
        }
      }
      resources {
        network {
          port "http" {}
        }
      }
      service {
        name = "authdemo-app"
        port = "http"
      }
    }

    task "auth" {
      driver = "docker"
      config {
        image = "liquidinvestigations/authproxy"
        labels {
          liquid_task = "authdemo-auth"
        }
        port_map {
          http = 5000
        }
      }
      template {
        data = <<EOF
          {{range service "authdemo-app"}}
            UPSTREAM_APP_URL = http://{{.Address}}:{{.Port}}
          {{end}}
          DEBUG = {{key "liquid_debug"}}
          USER_HEADER_TEMPLATE = {}
          {{range service "core"}}
            LIQUID_INTERNAL_URL = http://{{.Address}}:{{.Port}}
          {{end}}
          LIQUID_PUBLIC_URL = http://{{key "liquid_domain"}}
          {{with secret "liquid/authdemo"}}
            SECRET_KEY = {{.Data.secret_key}}
          {{end}}
          {{with secret "liquid/authdemo.coreauth"}}
            LIQUID_CLIENT_ID = {{.Data.client_id}}
            LIQUID_CLIENT_SECRET = {{.Data.client_secret}}
          {{end}}
        EOF
        destination = "local/docker.env"
        env = true
      }
      resources {
        network {
          port "http" {}
        }
      }
      service {
        name = "authdemo"
        port = "http"
      }
    }
  }
}
