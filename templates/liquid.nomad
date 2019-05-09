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
          "traefik.enable=true",
          "traefik.frontend.rule=Host:${liquid_domain}",
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

  group "ingress" {
    task "admin-authproxy" {
      driver = "docker"
      config {
        image = "liquidinvestigations/authproxy"
        labels {
          liquid_task = "ingress-admin-authproxy"
        }
        port_map {
          http = 5000
        }
      }
      template {
        data = <<EOF
          {{- range service "traefik-admin-internal" }}
            UPSTREAM_APP_URL = http://{{.Address}}:{{.Port}}
          {{- end }}
          DEBUG = {{key "liquid_debug"}}
          USER_HEADER_TEMPLATE = {}
          {{- range service "core" }}
            LIQUID_INTERNAL_URL = http://{{.Address}}:{{.Port}}
          {{- end }}
          LIQUID_PUBLIC_URL = http://{{key "liquid_domain"}}
          {{- with secret "liquid/admin/auth.django" }}
            SECRET_KEY = {{.Data.secret_key}}
          {{- end }}
          {{- with secret "liquid/admin/auth.oauth2" }}
            LIQUID_CLIENT_ID = {{.Data.client_id}}
            LIQUID_CLIENT_SECRET = {{.Data.client_secret}}
          {{- end }}
        EOF
        destination = "local/docker.env"
        env = true
      }
      resources {
        memory = 100
        network {
          port "http" {}
        }
      }
      service {
        name = "traefik-admin"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:admin.${liquid_domain}",
        ]
      }
    }

    task "traefik" {
      driver = "docker"
      config {
        image = "traefik:1.7"
        port_map {
          http = 80
          dashboard = 8080
          admin_internal = 8888
          {%- if https_enabled %}
          https = 443
          {%- endif %}
        }
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml:ro",
          "${consul_socket}:/consul.sock:ro",
          "${liquid_volumes}/liquid/traefik/acme:/etc/traefik/acme",
        ]
        labels {
          liquid_task = "liquid-ingress"
        }
      }
      template {
        data = <<-EOF
          debug = {{ key "liquid_debug" }}
          {%- if https_enabled %}
          defaultEntryPoints = ["http", "https"]
          {%- else %}
          defaultEntryPoints = ["http"]
          {%- endif %}

          [traefikLog]
          filePath = "/dev/stderr"

          [accessLog]
          filePath = "/dev/stdout"

          [api]
          entryPoint = "dashboard"

          [entryPoints]
            [entryPoints.http]
            address = ":80"

              {%- if https_enabled %}
              [entryPoints.http.redirect]
              entryPoint = "https"
              {%- endif %}

            [entryPoints.dashboard]
            address = ":8080"

            [entryPoints.admin_internal]
            address = ":8888"

            {%- if https_enabled %}
            [entryPoints.https]
            address = ":443"
              [entryPoints.https.tls]
            {%- endif %}

          [file]

          [backends]
            [backends.nomad]
            [backends.nomad.servers]
            [backends.nomad.servers.the_server]
            url = "${nomad_url}"
            [backends.nomad.healthCheck]
            type = "http"
            initial_status = "critical"
            name = "nomad alive on http /v1/status/leader"
            path = "/v1/status/leader"
            interval = "${check_interval}"
            timeout = "${check_timeout}"

          [frontends]
            [frontends.nomad]
            entryPoint = "admin_internal"
            backend = "nomad"
            [frontends.nomad.routes]
            [frontends.nomad.routes.route0]
            rule = "Host:admin.${liquid_domain};PathPrefixStrip:/nomad"

          {%- if https_enabled %}
          [acme]
            email = "${acme_email}"
            entryPoint = "https"
            storage = "liquid/traefik/acme"
            onHostRule = true
            caServer = "${acme_caServer}"
            acmeLogging = true
            [acme.httpChallenge]
              entryPoint = "http"
          {%- endif %}


          [consulCatalog]
          endpoint = "unix:///consul.sock"
          prefix = "traefik"
          exposedByDefault = false

          [consul]
          endpoint = "unix:///consul.sock"
          prefix = "traefik"
        EOF
        destination = "local/traefik.toml"
      }
      resources {
        memory = 100
        network {
          port "http" {
            static = ${liquid_http_port}
          }
          port "admin_internal" {}
          port "dashboard" {}

          {%- if https_enabled %}
          port "https" {
            static = ${liquid_https_port}
          }
          {%- endif %}
        }
      }
      service {
        name = "traefik-http"
        port = "http"
        {%- if not https_enabled %}
        check {
          name = "traefik alive on http - home page"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["${liquid_domain}"]
          }
        }
        {%- endif %}
      }

      {%- if https_enabled %}
      service {
        name = "traefik-https"
        port = "https"
        check {
          name = "traefik alive on https - home page"
          initial_status = "critical"
          type = "http"
          protocol = "https"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          tls_skip_verify = true
          header {
            Host = ["${liquid_domain}"]
          }
        }
      }
      {%- endif %}

      service {
        name = "traefik-dashboard"
        port = "dashboard"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.entryPoint=admin_internal",
          "traefik.frontend.rule=Host:admin.${liquid_domain};PathPrefixStrip:/traefik",
        ]
        check {
          name = "traefik alive on dashboard"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }

      service {
        name = "traefik-admin-internal"
        port = "admin_internal"
      }
    }
  }
}
