{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "matrix" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  group "synapse" {
    ${ group_disk() }
    ${ continuous_reschedule() }

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
      }
      template {
        data = <<-EOFF
        echo "starting..."

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
      - names: [client{% if config.matrix_federation_domains %}, federation{% endif %}]
        compress: false
#   - port: 9009
#     tls: false
#     type: http
#     x_forwarded: true
#     resources:
#       - names: [federation]
#         compress: false
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
federation_domain_whitelist: [${config.matrix_federation_domains}]

media_store_path: /data/media_store
report_stats: false
serve_server_wellknown: true
require_auth_for_profile_requests: true
limit_profile_requests_to_users_who_share_rooms: true
allow_public_rooms_without_auth: false
allow_public_rooms_over_federation: false
allow_profile_lookup_over_federation: false
allow_device_name_lookup_over_federation: false
enable_registration: false
enable_3pid_lookup: false

presence:
  enabled: true
retention:
  enabled: true
  default_policy:
    min_lifetime: 1d
    max_lifetime: ${config.matrix_message_lifetime}
  allowed_lifetime_min: 1d
  allowed_lifetime_max: ${config.matrix_message_lifetime}
  purge_jobs:
    - longest_max_lifetime: 30d
      interval: 4h
    - shortest_max_lifetime: 30d
      interval: 7d

media_retention:
  local_media_lifetime: ${config.matrix_media_lifetime}
  remote_media_lifetime: ${config.matrix_media_lifetime}

auto_join_rooms:
  - "#welcome:matrix.${config.liquid_domain}"
  - "#maintenance:matrix.${config.liquid_domain}"
  - "#feedback:matrix.${config.liquid_domain}"
autocreate_auto_join_rooms: true
autocreate_auto_join_rooms_federated: false
autocreate_auto_join_room_preset: public_chat

session_lifetime: ${config.matrix_session_lifetime}
refresh_token_lifetime: ${config.matrix_session_lifetime}
nonrefreshable_access_token_lifetime: ${config.matrix_session_lifetime}

oidc_providers:
  - idp_id: liquid_core
    idp_name: "Liquid Investigations - CLICK HERE"
    user_profile_method: "userinfo_endpoint"
    discover: false
    pkce_method: never
    skip_verification: true

    issuer: "http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/o/"
    token_endpoint: "http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/o/token/"
    userinfo_endpoint: "http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/accounts/profile"
    # jwks_uri: "http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/o/token/"

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
}

