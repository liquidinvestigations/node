job "reup" {
  datacenters = ["dc1"]
  type = "service"

  group "web" {
    task "revive" {
      driver = "docker"
      config {
        image = "liquidinvestigations/reup"
        volumes = [
          "__LIQUID_VOLUMES__/reup/database:/opt/hoover/reup/reup/database",
        ]
        port_map {
          http = 8000
        }
        labels {
          liquid_task = "reup"
        }
      }
      env {
        SECRET_KEY = "TODO change me"
      }
      template {
        data = <<EOF
            {{- if keyExists "liquid_debug" }}
              DEBUG = {{ key "liquid_debug" }}
            {{- end }}
            REUP_HOSTNAME = reup.{{ key "liquid_domain" }}
          EOF
        destination = "local/reup.env"
        env = true
      }
      resources {
        memory = 200
        network {
          port "http" {}
        }
      }
      service {
        name = "reup"
        port = "http"
      }
    }
  }
}
