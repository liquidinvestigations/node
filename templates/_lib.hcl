{%- macro continuous_reschedule() %}
    restart {
      attempts = 5
      delay    = "20s"
      interval = "2m"
      mode     = "fail"
    }

    reschedule {
      attempts       = 0
      delay          = "15s"
      delay_function = "exponential"
      max_delay      = "10m"
      unlimited      = true
    }
{%- endmacro %}

{%- macro shutdown_delay() %}
      shutdown_delay = "0s"
      kill_timeout = "120s"
{%- endmacro %}

{%- macro task_logs() %}
logs {
  max_files     = 3
  max_file_size = 3
}
{%- endmacro %}

{%- macro group_disk(size=20) %}
ephemeral_disk {
  size = ${size}
  sticky = true
}
{%- endmacro %}

{%- macro authproxy_group(name, host, upstream=None, hypothesis_user_header = false, skip_button=True) %}
  group "authproxy" {
    ${ group_disk() }
    spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

    ${ continuous_reschedule() }

    task "authproxy-web" {
      ${ task_logs() }

      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = -99
      }

      driver = "docker"
      config {
        image = "${config.image('liquid-authproxy')}"
        volumes = [
          ${liquidinvestigations_authproxy_repo}
        ]
        labels {
          liquid_task = "${name}-authproxy"
        }
        port_map {
          authproxy = 5000
        }

        memory_hard_limit = 1500
      }

      template {
        data = <<-EOF
          {{- with secret "liquid/${name}/auth.oauth2" }}
            OAUTH2_PROXY_CLIENT_ID = {{.Data.client_id | toJSON }}
            OAUTH2_PROXY_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
          {{- end }}
          OAUTH2_PROXY_EMAIL_DOMAINS = *
          OAUTH2_PROXY_HTTP_ADDRESS = "0.0.0.0:5000"
          OAUTH2_PROXY_PROVIDER = "liquid"
          {{- range service "core" }}
            OAUTH2_PROXY_REDEEM_URL = "http://{{.Address}}:{{.Port}}/o/token/"
            OAUTH2_PROXY_PROFILE_URL = "http://{{.Address}}:{{.Port}}/accounts/profile"
          {{- end }}
          OAUTH2_PROXY_REDIRECT_URL = "${config.app_url(name)}/oauth2/callback"

          {{- range service "${upstream}" }}
            OAUTH2_PROXY_UPSTREAMS="http://{{.Address}}:{{.Port}}"
          {{- end }}

          OAUTH2_PROXY_REVERSE_PROXY = true
          OAUTH2_PROXY_SKIP_AUTH_REGEX = "/favicon\\.ico"
          OAUTH2_PROXY_SKIP_AUTH_STRIP_HEADERS = true
          {% if skip_button %}
            OAUTH2_PROXY_SKIP_PROVIDER_BUTTON = true
          {% endif %}
          OAUTH2_PROXY_SET_XAUTHREQUEST = true
          #OAUTH2_PROXY_SCOPE = "openid email profile read_user"
          OAUTH2_PROXY_SCOPE = "write read"
          OAUTH2_PROXY_OIDC_GROUPS_CLAIM = "roles"
          OAUTH2_PROXY_PASS_USER_HEADERS = true
          OAUTH2_PROXY_PASS_ACCESS_TOKEN = true
          # OAUTH2_PROXY_PASS_AUTHORIZATION_HEADER  = true

          OAUTH2_PROXY_COOKIE_NAME = "_oauth2_proxy_${name}_${config.liquid_domain}"
          OAUTH2_PROXY_COOKIE_SAMESITE = "lax"
          OAUTH2_PROXY_COOKIE_SECURE = {% if config.https_enabled %}true{% else %}false{% endif %}
          OAUTH2_PROXY_COOKIE_EXPIRE = "${config.auth_auto_logout}"
          # must be less than the other one
          # also, our provider doesn't support it
          #OAUTH2_PROXY_COOKIE_REFRESH = "${config.auth_auto_logout}"

          OAUTH2_PROXY_COOKIE_HTTPONLY = "true"
          OAUTH2_PROXY_COOKIE_SESSION_COOKIE_MINIMAL = "true"

          {{- with secret "liquid/${name}/cookie" }}
            OAUTH2_PROXY_COOKIE_SECRET = {{.Data.cookie | toJSON }}
          {{- end }}

          OAUTH2_PROXY_WHITELIST_DOMAINS = ".${config.liquid_domain}"
          OAUTH2_PROXY_SILENCE_PING_LOGGING = true
          OAUTH2_PROXY_REQUEST_LOGGING = false

          {%- if hypothesis_user_header %}
            LIQUID_ENABLE_HYPOTHESIS_HEADERS = true
          {%- endif %}

          LIQUID_DOMAIN = ${config.liquid_domain}
          LIQUID_HTTP_PROTOCOL = ${config.liquid_http_protocol}
          EOF
        destination = "local/docker.env"
        env = true
      }
      resources {
        network {
          mbits = 1
          port "authproxy" {}
        }
        memory = 150
        cpu = 150
      }
      service {
        name = "${name}-authproxy"
        port = "authproxy"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:${host}",
        ]
        check {
          name = "ping"
          initial_status = "critical"
          type = "http"
          path = "/ping"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
        check_restart {
          limit = 3
          grace = "35s"
        }
      }
    }
  }
{%- endmacro %}

{%- macro authproxy_group_old(name, host, upstream, threads=16, memory=300, user_header_template="{}", count=1) %}
  group "authproxy" {
    ${ group_disk() }
    spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

    ${ continuous_reschedule() }

    count = ${count}

    task "authproxy-web" {
      ${ task_logs() }

      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = -99
      }

      driver = "docker"
      config {
        image = "liquidinvestigations/authproxy:0.3.6"
        labels {
          liquid_task = "${name}-authproxy"
        }
        port_map {
          authproxy = 5000
        }
        memory_hard_limit = ${memory * 10}
      }
      template {
        data = <<-EOF
          CONSUL_URL = ${consul_url|tojson}
          UPSTREAM_SERVICE = ${upstream|tojson}
          DEBUG = {{key "liquid_debug" | toJSON }}
          USER_HEADER_TEMPLATE = ${user_header_template|tojson}
          LIQUID_CORE_SERVICE = "core"
          LIQUID_PUBLIC_URL = "${config.liquid_http_protocol}://{{key "liquid_domain"}}"
          {{- with secret "liquid/${name}/auth.django" }}
            SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          {{- with secret "liquid/${name}/auth.oauth2" }}
            LIQUID_CLIENT_ID = {{.Data.client_id | toJSON }}
            LIQUID_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
          {{- end }}
          THREADS = ${threads}
          EOF
        destination = "local/docker.env"
        env = true
      }
      resources {
        network {
          mbits = 1
          port "authproxy" {}
        }
        memory = ${memory}
        cpu = 150
      }
      service {
        name = "${name}-authproxy-old"
        port = "authproxy"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:${host}",
        ]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/__auth/logout"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
        check_restart {
          limit = 3
          grace = "35s"
        }
      }
    }
  }
{%- endmacro %}


{%- macro set_pg_password_template(username) %}
  template {
    data = <<-EOF
    #!/bin/bash
    set -e
    sed -i 's/host all all all trust/host all all all md5/' $PGDATA/pg_hba.conf
    psql -U ${username} -c "ALTER USER ${username} password '$POSTGRES_PASSWORD'"
    echo "password set for postgresql host=$(hostname) user=${username}" >&2
    EOF
    destination = "local/set_pg_password.sh"
  }
{%- endmacro %}
