{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "matrix" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  group "core-https-proxy" {

    ${ continuous_reschedule() }
    ${ group_disk() }

    task "core-https-proxy" {
      ${ task_logs() }

      driver = "docker"

      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = -99
      }

      config {
        image = "nginx:1.19"
        args = ["bash", "/local/startup.sh"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/matrix/oidc-selfhosted-certificate:/data:ro",
        ]
        port_map {
          https = 8080
        }
        labels {
          liquid_task = "core-https-proxy"
        }
        memory_hard_limit = 1024
      }

      resources {
        memory = 128
        network {
          mbits = 1
          port "https" {}
        }
      }

      template {
        data = <<-EOF
        #!/bin/bash
        set -ex

        cat /local/nginx.conf
        nginx -c /local/nginx.conf
        EOF
        env = false
        destination = "local/startup.sh"
      }

      template {
        data = <<-EOF

        daemon off;

        {% if config.liquid_debug %}
          error_log /dev/stderr debug;
        {% else %}
          error_log /dev/stderr info;
        {% endif %}

        worker_rlimit_nofile 8192;
        worker_processes 1;
        events {
          worker_connections 4096;
        }

        http {
          access_log  /dev/stdout;
          default_type  application/octet-stream;
          include       /etc/nginx/mime.types;

          tcp_nopush   on;
          server_names_hash_bucket_size 128;
          sendfile on;
          sendfile_max_chunk 4m;
          aio threads;
          limit_rate 66m;

          upstream fabio {
            server {{env "attr.unique.network.ip-address"}}:${config.port_lb};
          }

          server {
            listen 8080 default_server ssl;
            listen [::]:8080 default_server ssl;

            ssl_certificate         /data/certs/nginx-selfsigned.crt;
            ssl_certificate_key     /data/private/nginx-selfsigned.key;

            server_name core-oidc.local;

            proxy_http_version  1.1;
            proxy_cache_bypass  $http_upgrade;
            proxy_connect_timeout 159s;
            proxy_send_timeout   150;
            proxy_read_timeout   150;
            proxy_buffer_size    64k;
            proxy_buffers     16 32k;
            proxy_busy_buffers_size 64k;
            proxy_temp_file_write_size 64k;

            proxy_set_header Upgrade           $http_upgrade;
            proxy_set_header Connection        "upgrade";
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
            proxy_set_header X-Forwarded-Host  $host;
            proxy_set_header X-Forwarded-Port  $server_port;
            proxy_pass_request_headers      on;

            client_max_body_size 5M;

            location  / {
              proxy_pass http://fabio/_core;
            }
          }
        }
        EOF
        destination = "local/nginx.conf"
      }

      service {
        name = "core-https-proxy"
        port = "https"
        tags = ["fabio-:${config.port_liquid_core_web_https} proto=tcp"]
        check {
          name = "ping"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
        check_restart {
          limit = 5
          grace = "995s"
        }
      }
    }
  }


  group "synapse" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    # network {
    #   mode = "bridge"

    #   port "net-http" {
    #     static = 8008
    #     to     = 8008
    #   }
    # }

    # service {
    #   name = "cc-matrix-synapse-http"
    #   port = "net-http"

    #   # connect {
    #   #   sidecar_service {
    #   #     proxy {
    #   #       upstreams {
    #   #         destination_name = "cc-core-http"
    #   #         local_bind_port  = 12345
    #   #       }
    #   #     }
    #   #   }
    #   # }
    # }

    task "synapse" {
      # failed to write file
      user = "991:991"
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }
      driver = "docker"
      config {
        image = "${config.image('matrix-synapse')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/matrix/synapse-Z/files:/data",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/matrix/oidc-selfhosted-certificate/certs:/core-nginx-certs",
        ]
        port_map { http = 8008 }
        labels {
          liquid_task = "matrix_synapse"
        }
        memory_hard_limit = 2000
        entrypoint = ["/bin/sh", "/local/startup.sh"]
        extra_hosts = ["core-oidc.local:{% raw %}${attr.unique.network.ip-address}{% endraw %}"]
      }
      template {
        data = <<-EOFF
        echo "starting..."

        ls -alh $SSL_CERT_FILE
        ls -alh /core-nginx-certs

        curl --version
        until curl  https://core-oidc.local:${config.port_liquid_core_web_https}/o/.well-known/openid-configuration/ ; do sleep 5; echo waiting for upstream; done
        echo https upstream found;

        for i in 1 2 3 4 5 6 7; do
          python /start.py || sleep 15
          echo "restarting $i..."
        done
        echo "failed."

        EOFF
        destination = "local/startup.sh"
      }

      env {
        SYNAPSE_CONFIG_PATH = "/local/homeserver.yaml"
        SYNAPSE_DATA_DIR = "/data"
        SSL_CERT_FILE = "/core-nginx-certs/nginx-selfsigned.crt"
      }

      template {
        data = <<-EOF
version: 1
formatters:
    precise:
        format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'
handlers:
    console:
        class: logging.StreamHandler
        formatter: precise
loggers:
    synapse.storage.SQL:
        # beware: increasing this to DEBUG will make synapse log sensitive
        # information such as access tokens.
        level: WARNING
root:
    level: WARNING
    handlers: [console]
disable_existing_loggers: false
        EOF
        destination = "local/log.config"
      }

      template {
        data = <<-EOF
# For more information on how to configure Synapse, including a complete accounting of
# each option, go to docs/usage/configuration/config_documentation.md or
# https://matrix-org.github.io/synapse/latest/usage/configuration/config_documentation.html

server_name: "matrix.${config.liquid_domain}"
public_baseurl: "${config.liquid_http_protocol}://matrix.${config.liquid_domain}"
web_client_location: "${config.liquid_http_protocol}://matrix-ui.${config.liquid_domain}"


listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    resources:
      - names: [client, federation]
        compress: false
database:
  name: psycopg2
  txn_limit: 1000
  args:
    user: matrix
    password: {{ with secret "liquid/matrix/matrix.postgres" }}{{.Data.secret_key | toJSON }}{{ end }}
    database: matrix
    host: {{env "attr.unique.network.ip-address" }}
    port: ${config.port_matrix_pg}
    cp_min: 2
    cp_max: 10

log_config: "/local/log.config"
pid_file: /data/homeserver.pid
signing_key_path: "/data/matrix.${config.liquid_domain}.signing.key"
macaroon_secret_key: {{ with secret "liquid/matrix/maca.secret" }}{{.Data.secret_key | toJSON }}{{ end }}
form_secret: {{ with secret "liquid/matrix/form.secret" }}{{.Data.secret_key | toJSON }}{{ end }}


trusted_key_servers: []
federation_domain_whitelist: []

media_store_path: /data/media_store
report_stats: false
serve_server_wellknown: true
require_auth_for_profile_requests: true
limit_profile_requests_to_users_who_share_rooms: true
allow_public_rooms_without_auth: false
allow_public_rooms_over_federation: false
enable_registration: false
enable_3pid_lookup: false

presence:
  enabled: true
retention:
  enabled: true
  default_policy:
    min_lifetime: 1d
    max_lifetime: 1y
  allowed_lifetime_min: 1d
  allowed_lifetime_max: 1y
  purge_jobs:
    - longest_max_lifetime: 3d
      interval: 12h
    - shortest_max_lifetime: 3d
      interval: 3d

oidc_providers:
  - idp_id: liquid_core
    idp_name: "Liquid Investigations - click here"
    user_profile_method: "userinfo_endpoint"
    discover: false
    pkce_method: never
    skip_verification: true

    # issuer: "${config.liquid_core_url}/o/"
    issuer: "https://core-oidc.local:${config.port_liquid_core_web_https}/o/"
    token_endpoint: "https://core-oidc.local:${config.port_liquid_core_web_https}/o/token/"
    userinfo_endpoint: "https://core-oidc.local:${config.port_liquid_core_web_https}/accounts/profile"
    jwks_uri: "https://core-oidc.local:${config.port_liquid_core_web_https}/o/.well-known/jwks.json"

    authorization_endpoint: "${config.liquid_core_url}/o/authorize/"

    client_id: {{ with secret "liquid/matrix/app.auth.oauth2" }}{{.Data.client_id | toJSON }}{{ end }}
    client_secret: {{ with secret "liquid/matrix/app.auth.oauth2" }}{{.Data.client_secret | toJSON }}{{ end }}

    # scopes: ["openid"]
    scopes: ["read"]

    user_mapping_provider:
      config:
        localpart_template: "{{"{{"}} user.email.split('@')[0] {{"}}"}}"
        display_name_template: "{{"{{"}} user.first_name {{"}}"}} {{"{{"}} user.last_name {{"}}"}}"
        email_template: "{{"{{"}} user.email {{"}}"}}"

sso:
  client_whitelist:
    - "${config.liquid_http_protocol}://matrix-ui.${config.liquid_domain}"
  update_profile_information: true

password_config:
  enabled: false

push:
  enabled: true
  include_content: false
  group_unread_count_by_room: false
  jitter_delay: "9s"

        EOF
        destination = "local/homeserver.yaml"
      }

      resources {
        memory = 450
        cpu = 150
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "matrix-synapse"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:matrix.${config.liquid_domain}",
          "fabio-:${config.port_matrix_synapse} proto=tcp",
        ]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/health"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "element" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "element" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }
      driver = "docker"
      config {
        image = "${config.image('matrix-element')}"
        volumes = [
          "local/config.json:/app/config.json:ro",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "matrix_element"
        }
        memory_hard_limit = 2000
      }


      template {
        data = <<-EOF

{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "${config.liquid_http_protocol}://matrix.${config.liquid_domain}",
            "server_name": "matrix.${config.liquid_domain}"
        }
    },
    "permalink_prefix": "${config.liquid_http_protocol}://matrix-ui.${config.liquid_domain}",
    "default_federate": false,

    "disable_custom_urls": true,
    "disable_guests": false,
    "disable_login_language_selector": false,
    "disable_3pid_login": true,

    "brand": "Liquid Investigations - Matrix / Element",

    "integrations_ui_url": null,
    "integrations_rest_url": null,
    "integrations_widgets_urls": null,

    "default_country_code": "GB",
    "show_labs_settings": false,
    "features": {},
    "default_theme": "light",
    "room_directory": { "servers": ["matrix.${config.liquid_domain}"] },
    "enable_presence_by_hs_url": { "${config.liquid_http_protocol}://matrix.${config.liquid_domain}": true },
    "setting_defaults": {
        "breadcrumbs": true,

        "UIFeature.urlPreviews": false,
        "UIFeature.feedback": false,
        "UIFeature.shareQrCode": false,
        "UIFeature.advancedSettings": false,
        "UIFeature.identityServer": false,
        "UIFeature.thirdPartyId": false,
        "UIFeature.registration": false,
        "UIFeature.passwordReset": false,
        "UIFeature.deactivate": false,
        "UIFeature.advancedEncryption": true,
        "UIFeature.roomHistorySettings": true,
        "UIFeature.BulkUnverifiedSessionsReminder": true,
        "UIFeature.locationSharing": false,

        "UIFeature.shareSocial": false
    },
    "jitsi": { "preferred_domain": "jitsi.${config.liquid_domain}" },

    "element_call": null,
    "map_style_url": null,

    "logout_redirect_url": "${config.liquid_core_url}/accounts/logout/?next=/",
    "sso_redirect_options": { "immediate": true }
}

        EOF
        destination = "local/config.json"
      }

      resources {
        memory = 450
        cpu = 150
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "matrix-element"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:matrix-ui.${liquid_domain}",
          "fabio-:${config.port_matrix_element} proto=tcp",
        ]
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

  group "jitsi-web" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "jitsi-web" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }
      driver = "docker"
      config {
        image = "${config.image('jitsi-web')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/matrix/jitsi:/data",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "matrix_jitsi"
        }
        memory_hard_limit = 2000
      }

      env {
        matrix_GITHUB_SERVER = "https://github.com"
      }

      template {
        data = <<-EOF

        matrix_SECRET_SKIP_VERIFY = "true"

        EOF
        destination = "local/matrix.env"
        env = true
      }

      resources {
        memory = 450
        cpu = 150
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "matrix-jitsi"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:jitsi.${liquid_domain}",
          "fabio-:${config.port_matrix_jitsi} proto=tcp",
        ]
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

