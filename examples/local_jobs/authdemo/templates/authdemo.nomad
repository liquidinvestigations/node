{% from '_lib.hcl' import authproxy_group with context -%}

job "authdemo" {
  datacenters = ["dc1"]
  type = "service"

  group "demo" {
    task "app" {
      driver = "docker"
      config {
        # runs this very simple script:
        # https://github.com/liquidinvestigations/authproxy/blob/v0.3.2/testapp.py#L10
        image = "liquidinvestigations/authproxy:0.3.2"
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
  }

  ${- authproxy_group(
      'authdemo',
      host='authdemo.' + liquid_domain,
      upstream='authdemo-app',
    ) }
}
