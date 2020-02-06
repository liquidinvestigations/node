{%- macro airflow_env_template() %}
      template {
        data = <<-EOF
        {{- range service "snoop-${name}-airflow-pg" }}
          AIRFLOW__CORE__SQL_ALCHEMY_CONN = "postgresql+psycopg2://airflow:
          {{- with secret "liquid/collections/${name}/airflow.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{.Address}}:{{.Port}}/airflow"
        {{- end }}
        {{ range service "dask-scheduler-${name}" -}}
          AIRFLOW__DASK__CLUSTER_ADDRESS = "{{.Address}}:{{.Port}}"
        {{- end }}
        {{ range service "telegraf" -}}
          AIRFLOW__SCHEDULER__STATSD_HOST = "{{.Address}}"
        {{- end }}
        {{ range service "telegraf" -}}
          AIRFLOW__SCHEDULER__STATSD_PORT = "8125"
        {{- end }}
        AIRFLOW__WEBSERVER__BASE_URL = "http://"{%raw%}${attr.unique.network.ip-address}{%endraw%}":8765/_airflow/${name}"

        {{ range service "snoop-${name}-airflow-minio" -}}
          AIRFLOW_MINIO_LOGS_EXTRA = " {
          {{- with secret "liquid/collections/${name}/logs.minio.key" -}}
            \"aws_access_key_id\": \"{{.Data.secret_key}}\",
          {{- end -}}
          {{- with secret "liquid/collections/${name}/logs.minio.secret" -}}
            \"aws_secret_access_key\": \"{{.Data.secret_key}}\",
          {{- end -}}
          \"host\": \"http://{{.Address}}:{{.Port}}\" }"
        {{- end -}}
        EOF
        destination = "local/airflow.env"
        env = true
      }
{%- endmacro %}

{%- macro dask_env_template() %}
      env {
        "DASK_DISTRIBUTED__ADMIN__TICK__INTERVAL" = "1000ms"
        "DASK_DISTRIBUTED__WORKER__PROFILE__INTERVAL" = "100ms"
        "DASK_DISTRIBUTED__WORKER__PROFILE__CYCLE" = "10000ms"
        "DASK_DISTRIBUTED__SCHEDULER__WORK_STEALING" = "True"
        "DASK_DISTRIBUTED__SCHEDULER__ALLOWED_FAILURES" = "2"
      }
{%- endmacro %}

{%- macro continuous_reschedule() %}
{%- endmacro %}

{%- macro task_logs() %}
logs {
  max_files     = 5
  max_file_size = 1
}
{%- endmacro %}

{%- macro group_disk(size=50) %}
ephemeral_disk {
  size = ${size}
}
{%- endmacro %}

{%- macro authproxy_group(name, host, upstream, threads=24, memory=200, user_header_template="{}", count=1) %}
  group "authproxy" {
    restart {
      interval = "2m"
      attempts = 4
      delay = "20s"
      mode = "delay"
    }

    count = ${count}

    task "web" {
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
          interval = "3s"
          timeout = "2s"
        }
      }
    }

    ${ promtail_task() }
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

{% macro promtail_task() %}
    task "promtail" {
      driver = "docker"

      ${ task_logs() }

      config {
        image = "grafana/promtail:master"
        args = ["-config.file", "local/config.yaml"]
        dns_servers = ["{%raw%}${attr.unique.network.ip-address}{%endraw%}"]
      }

      template {
        destination = "local/config.yaml"
        data = <<-EOH
          positions:
            filename: /tmp/positions.yaml
          client:
            url: http://cluster-fabio.service.consul:9990/loki/api/prom/push
          scrape_configs:
          - job_name: system
            entry_parser: raw
            static_configs:
            - targets:
                - localhost
              labels:
                job: {{ env "NOMAD_JOB_NAME" }}
                group: {{ env "NOMAD_GROUP_NAME" }}
                __path__: /alloc/logs/*
          EOH
      }

      resources {
        cpu = 50
        memory = 32
        network { mbits = 1 }
      }
    }
{% endmacro %}
