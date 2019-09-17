{% from '_lib.hcl' import authproxy_group, promtail_task with context -%}

job "etherpad" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  group "etherpad" {
    task "etherpad" {
      leader = true
      driver = "docker"
      config {
        image = "${config.image('etherpad-lite')}"
        port_map {
          http = 8080
        }
        labels {
          liquid_task = "etherpad"
        }
      }
      resources {
        cpu = 100
        memory = 150
        network {
          mbits = 1
          port "http" {}
        }
      }
      env {
        NODE_ENV = "production"
        TITLE = "${config.liquid_title}"
        PORT = "8080"
        POSTGRES_USER = "etherpad"
        POSTGRES_DATABASE = "etherpad"
        LOGLEVEL = "DEBUG"
      }
      template {
        data = <<-EOF
        {{- range service "etherpad-pg" }}
          POSTGRES_HOST = {{.Address | toJSON}}
          POSTGRES_PORT = {{.Port | toJSON}}
        {{- end }}

        {{- with secret "liquid/etherpad/etherpad.postgres" }}
          POSTGRES_PASSWORD = {{.Data.secret_key | toJSON}}
        {{- end }}
        EOF
        destination = "local/etherpad-pg.env"
        env = true
      }

      template {
        data = <<-EOF
        EP_OAUTH2_AUTHORIZATION_URL="${config.liquid_core_url}/o/authorize/"
        EP_OAUTH2_USERNAME_KEY="name"
        EP_OAUTH2_USERID_KEY="name"
        EP_OAUTH2_PUBLIC_URL="${config.app_url('etherpad')}"

        {{- range service "core" }}
          EP_OAUTH2_TOKEN_URL="http://{{.Address}}:{{.Port}}/o/token/"
          EP_OAUTH2_USERINFO_URL="http://{{.Address}}:{{.Port}}/accounts/profile"
        {{- end }}
        {{- with secret "liquid/etherpad/auth.oauth2" }}
          EP_OAUTH2_CLIENT_ID={{.Data.client_id | toJSON }}
          EP_OAUTH2_CLIENT_SECRET={{.Data.client_secret | toJSON }}
        {{- end }}
        EOF

        destination = "local/etherpad-auth.env"
        env = true
      }
      service {
        name = "etherpad-app"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:etherpad.${liquid_domain}",
        ]
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    ${ promtail_task() }
  }

  group "db" {
    task "postgres" {
      leader = true
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "postgres:11.5"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/etherpad/postgres:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "etherpad-pg"
        }
        port_map {
          pg = 5432
        }
      }
      template {
        data = <<-EOF
        POSTGRES_DB = "etherpad"
        POSTGRES_USER = "etherpad"
        {{- with secret "liquid/etherpad/etherpad.postgres" }}
          POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}
        EOF
        destination = "local/pg.env"
        env = true
      }
      resources {
        cpu = 100
        memory = 200
        network {
          mbits = 1
          port "pg" { }
        }
      }
      service {
        name = "etherpad-pg"
        port = "pg"
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    ${ promtail_task() }
  }
}
