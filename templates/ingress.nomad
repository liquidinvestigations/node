{% from '_lib.hcl' import continuous_reschedule -%}

job "ingress" {
  datacenters = ["dc1"]
  type = "service"
  priority = 90

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
          endpoint = "${consul_url}"
          prefix = "traefik"
          exposedByDefault = false

          [consul]
          endpoint = "${consul_url}"
          prefix = "traefik"
        EOF
        destination = "local/traefik.toml"
      }
      resources {
        memory = 100
        network {
          mbits = 1
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
          name = "http"
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
          name = "https"
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
          name = "http"
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
