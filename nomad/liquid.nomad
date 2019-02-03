job "liquid" {
  datacenters = ["dc1"]
  type = "service"

  group "core" {
    task "core" {
      driver = "docker"
      config {
        image = "liquidinvestigations/core"
        labels {
          liquid_task = "liquid-core"
        }
        port_map {
          http = 8000
        }
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

  group "nginx" {
    task "nginx" {
      driver = "docker"
      template {
        data = <<EOF

          {{- if service "core" }}
            upstream core {
              {{- range service "core" }}
                server {{ .Address }}:{{ .Port }} fail_timeout=1s;
              {{- end }}
            }
            server {
              listen 80;
              server_name liquid.example.org;
              location / {
                proxy_pass http://core;
                proxy_set_header Host $host;
              }
            }
          {{- end }}

          {{- if service "hoover" }}
            upstream hoover {
              {{- range service "hoover" }}
                server {{ .Address }}:{{ .Port }} fail_timeout=1s;
              {{- end }}
            }
            server {
              listen 80;
              server_name hoover.liquid.example.org;
              location / {
                proxy_pass http://hoover;
                proxy_set_header Host $host;
              }
            }
          {{- end }}

          {{- if service "snoop-testdata-api" }}
            upstream snoop-testdata-api {
              {{- range service "snoop-testdata-api" }}
                server {{ .Address }}:{{ .Port }} fail_timeout=1s;
              {{- end }}
            }
            server {
              listen 80;
              server_name testdata.snoop.liquid.example.org;
              location / {
                proxy_pass http://snoop-testdata-api;
                proxy_set_header Host $host;
              }
            }
          {{- end }}

          server {
            listen 80 default_server;
            location / {
              default_type "text/plain";
              return 404 "Unknown domain $host\n";
            }
          }

          EOF
        destination = "local/core.conf"
      }
      config = {
        image = "nginx"
        port_map {
          http = 80
        }
        volumes = [
          "local/core.conf:/etc/nginx/conf.d/core.conf",
        ]
        labels {
          liquid_task = "liquid-nginx"
        }
      }
      resources {
        network {
          port "http" {
            static = 80
          }
        }
      }
      service {
        name = "nginx"
        tags = ["global"]
        port = "http"
      }
    }
  }
}
