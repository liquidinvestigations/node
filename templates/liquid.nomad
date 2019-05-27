{% from '_lib.hcl' import continuous_reschedule -%}

job "liquid" {
  datacenters = ["dc1"]
  type = "service"

  group "core" {
    ${ continuous_reschedule() }

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
          {{- with secret "liquid/liquid/core.django" }}
            SECRET_KEY = {{.Data.secret_key}}
          {{- end }}
          LIQUID_HTTP_PROTOCOL = ${config.liquid_http_protocol}
          LIQUID_DOMAIN = {{key "liquid_domain"}}
          SERVICE_ADDRESS = {{env "NOMAD_IP_http"}}
          LIQUID_2FA = ${config.liquid_2fa}
          HOOVER_APP_URL = ${config.liquid_http_protocol}://hoover.${config.liquid_domain}
          DOKUWIKI_APP_URL = ${config.liquid_http_protocol}://dokuwiki.${config.liquid_domain}
          ROCKETCHAT_APP_URL = ${config.liquid_http_protocol}://rocketchat.${config.liquid_domain}
          NEXTCLOUD_APP_URL = ${config.liquid_http_protocol}://nextcloud.${config.liquid_domain}
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
          header {
            Host = ["${liquid_domain}"]
          }
        }
      }
    }
  }

  group "ingress" {
    ${ continuous_reschedule() }

    task "traefik" {
      driver = "docker"
      config {
        image = "traefik:1.7"
        port_map {
          http = 80
          admin = 8080
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
          logLevel = "INFO"

          debug = {{ key "liquid_debug" }}
          {%- if https_enabled %}
          defaultEntryPoints = ["http", "https"]
          {%- else %}
          defaultEntryPoints = ["http"]
          {%- endif %}

          [api]
          entryPoint = "admin"

          [entryPoints]
            [entryPoints.http]
            address = ":80"

              {%- if https_enabled %}
              [entryPoints.http.redirect]
              entryPoint = "https"
              {%- endif %}

            [entryPoints.admin]
            address = ":8080"

            {%- if https_enabled %}
            [entryPoints.https]
            address = ":443"
              [entryPoints.https.tls]
            {%- endif %}

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
          port "admin" {
            static = 8766
          }

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
        name = "traefik-admin"
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
