{%- macro continuous_reschedule() %}
    restart {
      attempts = 5
      delay    = "11s"
      interval = "3m"
      mode     = "fail"
    }
    reschedule {
      attempts       = 0
      delay          = "11s"
      delay_function = "exponential"
      max_delay      = "19m"
      unlimited      = true
    }
{%- endmacro %}

{%- macro shutdown_delay() %}
      shutdown_delay = "0s"
      kill_timeout = "29s"
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
}
{%- endmacro %}

{%- macro authproxy_group(name, host, upstream, threads=24, memory=300, user_header_template="{}", count=1) %}
  group "authproxy" {
    ${ group_disk() }
    spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

    restart {
      interval = "2m"
      attempts = 4
      delay = "20s"
      mode = "delay"
    }

    count = ${count}

    task "authproxy-web" {
      ${ task_logs() }

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
        name = "${name}-authproxy"
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
          interval = "6s"
          timeout = "3s"
        }
        check_restart {
          limit = 3
          grace = "55s"
        }
      }
    }
  }
{%- endmacro %}

{%- macro set_pg_password_template(username) %}
  template {
    data = <<-EOF
    #!/bin/sh
    set -e
    sed -i 's/host all all all trust/host all all all md5/' $PGDATA/pg_hba.conf
    psql -U ${username} -c "ALTER USER ${username} password '$POSTGRES_PASSWORD'"
    echo "password set for postgresql host=$(hostname) user=${username}" >&2
    EOF
    destination = "local/set_pg_password.sh"
  }
{%- endmacro %}
