job "hoover" {
  datacenters = ["dc1"]
  type = "service"

  group "deps" {
    task "es" {
      driver = "docker"
      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch:6.2.4"
        volumes = [
          "/var/local/liquid/volumes/hoover/es/data:/usr/share/elasticsearch/data",
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
        # TODO https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html#_notes_for_production_use_and_defaults
      }
      resources {
        memory = 1536
        network {
          port "es" {}
        }
      }
      service {
        name = "hoover-es"
        port = "es"
      }
    }

    task "pg" {
      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "/var/local/liquid/volumes/hoover/pg/data:/var/lib/postgresql/data",
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
        network {
          port "pg" {}
        }
      }
      service {
        name = "hoover-pg"
        port = "pg"
      }
    }
  }

  group "web" {
    task "search" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-search:liquid-nomad"
        volumes = [
          "/var/local/liquid/volumes/hoover-ui/build:/opt/hoover/ui/build",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "hoover-search"
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
            HOOVER_DB = postgresql://hoover:hoover@
              {{- range service "hoover-pg" -}}
                {{ .Address }}:{{ .Port }}
              {{- end -}}
              /hoover
            HOOVER_ES_URL = http://
              {{- range service "hoover-es" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            HOOVER_HOSTNAME = hoover.{{ key "liquid_domain" }}
          EOF
        destination = "local/hoover.env"
        env = true
      }
      resources {
        network {
          port "http" {}
        }
      }
      service {
        name = "hoover"
        port = "http"
      }
    }
  }

  group "collections" {
    task "nginx" {
      driver = "docker"
      template {
        data = <<EOF
          server {
            listen 80 default_server;

            {{- if service "hoover-es" }}
              {{- with service "hoover-es" }}
                {{- with index . 0 }}
                  location ~ ^/_es/(.*) {
                    proxy_pass http://{{ .Address }}:{{ .Port }}/$1;
                  }
                {{- end }}
              {{- end }}
            {{- end }}

            {{- range services }}
              {{- if .Name | regexMatch "^snoop-" }}
                {{- with service .Name }}
                  {{- with index . 0 }}
                    location ~ ^/{{ .Name | regexReplaceAll "^(snoop-)" "" }}/(.*) {
                      proxy_pass http://{{ .Address }}:{{ .Port }}/$1;
                      proxy_set_header Host {{ .Name | regexReplaceAll "^(snoop-)" "" }}.snoop.{{ key "liquid_domain" }};
                    }
                  {{- end }}
                {{- end }}
              {{- end }}
            {{- end }}

          }

          {{- range services }}
            {{- if .Name | regexMatch "^snoop-" }}
              {{- with service .Name }}
                {{- with index . 0 }}
                  server {
                    listen 80;
                    server_name {{ .Name | regexReplaceAll "^(snoop-)" "" }}.snoop.{{ key "liquid_domain" }};
                    location / {
                      proxy_pass http://{{ .Address }}:{{ .Port }};
                      proxy_set_header Host $host;
                    }
                  }
                {{- end }}
              {{- end }}
            {{- end }}
          {{- end }}
          EOF
        destination = "local/collections.conf"
      }
      config = {
        image = "nginx"
        port_map {
          nginx = 80
        }
        volumes = [
          "local/collections.conf:/etc/nginx/conf.d/collections.conf",
        ]
        labels {
          liquid_task = "hoover-collections-nginx"
        }
      }
      resources {
        network {
          port "nginx" {
            static = 8765
          }
        }
      }
      service {
        name = "hoover-collections"
        port = "nginx"
      }
    }
  }
}
