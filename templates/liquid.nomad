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
              server_name {{ key "liquid_domain" }};
              location / {
                proxy_pass http://core;
                proxy_set_header Host $host;
              }
            }
          {{- end }}

          {{- if service "authdemo" }}
            upstream authdemo {
              {{- range service "authdemo" }}
                server {{ .Address }}:{{ .Port }} fail_timeout=1s;
              {{- end }}
            }
            server {
              listen 80;
              server_name authdemo.{{ key "liquid_domain" }};
              location / {
                proxy_pass http://authdemo;
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
              server_name hoover.{{ key "liquid_domain" }};
              location / {
                proxy_pass http://hoover;
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
          nginx = 80
        }
        volumes = [
          "local/core.conf:/etc/nginx/conf.d/core.conf",
        ]
        labels {
          liquid_task = "liquid-nginx"
        }
      }
      resources {
        memory = 50
        network {
          port "nginx" {
            static = ${liquid_http_port}
          }
        }
      }
      service {
        name = "ingress"
        port = "nginx"
        check {
          name = "nginx ingress forwards hoover /_ping"
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
          name = "nginx ingress forwards liquid-core /"
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
    }
  }
}
