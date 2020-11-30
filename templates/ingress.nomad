{% from '_lib.hcl' import continuous_reschedule, group_disk, task_logs -%}

job "ingress" {
  datacenters = ["dc1"]
  type = "service"
  priority = 90

  group "ingress" {
    ${ group_disk() }
    constraint {
      attribute = "{% raw %}${meta.liquid_ingress}{% endraw %}"
      operator  = "is_set"
    }
    ${ continuous_reschedule() }

    task "traefik" {
      ${ task_logs() }
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
        volumes = ["local/traefik.toml:/etc/traefik/traefik.toml:ro"]
        labels {
          liquid_task = "liquid-ingress"
        }
        memory_hard_limit = 300
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
                minVersion = "VersionTLS12"
                # https://ssl-config.mozilla.org/#server=traefik&version=1.7&config=intermediate&guideline=5.4
                cipherSuites = [
                  "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
                  "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
                  "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
                  "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
                  "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
                  "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
                ]
            {%- endif %}

          {%- if https_enabled %}
          [acme]
            email = "${acme_email}"
            entryPoint = "https"
            storage = "liquid/traefik/acme_new"
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
          prefix = "liquid/traefik/data"
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
        {% else %}
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
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
