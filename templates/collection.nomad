{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule, set_pg_password_template, promtail_task with context -%}

job "collection-${name}" {
  datacenters = ["dc1"]
  type = "service"
  priority = 55

  group "workers" {
    ${ group_disk() }

    count = ${workers}

    task "snoop" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      constraint {
        attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('hoover-snoop2')}"
        args = ["sh", "/local/startup.sh"]
        volumes = [
          ${hoover_snoop2_repo}
          "{% raw %}${meta.liquid_collections}{% endraw %}/${name}:/opt/hoover/collection",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/collections/${name}/blobs:/opt/hoover/snoop/blobs",
        ]
        port_map {
          flower = 5555
        }
        labels {
          liquid_task = "snoop-${name}-worker"
        }
      }
      env {
        SNOOP_COLLECTION_ROOT = "/opt/hoover/collection"
        SNOOP_TASK_PREFIX = "${name}"
        SNOOP_ES_INDEX = "${name}"
        SYNC_FILES = "${sync}"
      }
      template {
        data = <<-EOF
        #!/bin/sh
        set -ex
        if  [ -z "$SNOOP_TIKA_URL" ] \
                || [ -z "$SNOOP_DB" ] \
                || [ -z "$SNOOP_ES_URL" ] \
                || [ -z "$SNOOP_AMQP_URL" ]; then
          echo "incomplete configuration!"
          sleep 5
          exit 1
        fi
        exec ./manage.py runworkers
        EOF
        env = false
        destination = "local/startup.sh"
      }
      env {
        SNOOP_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8765/_es"
        SNOOP_STATS_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8765/_es"
        SNOOP_STATS_ES_PREFIX = ".hoover-snoopstats-"
        SNOOP_TIKA_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8765/_tika/"
      }
      template {
        data = <<-EOF
        {{- if keyExists "liquid_debug" }}
          DEBUG = {{key "liquid_debug" | toJSON }}
        {{- end }}
        {{- range service "snoop-${name}-pg" }}
          SNOOP_DB = "postgresql://snoop:
          {{- with secret "liquid/collections/${name}/snoop.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{.Address}}:{{.Port}}/snoop"
        {{- end }}
        {{- range service "snoop-${name}-rabbitmq" }}
          SNOOP_AMQP_URL = "amqp://{{.Address}}:{{.Port}}"
        {{- end }}
        {{ range service "zipkin" }}
          TRACING_URL = "http://{{.Address}}:{{.Port}}"
        {{- end }}
        EOF
        destination = "local/snoop.env"
        env = true
      }
      resources {
        memory = 400
        network {
          mbits = 1
          port "flower" {}
        }
      }
      service {
        name = "snoop-${name}-flower"
        port = "flower"
      }
    }

    ${ promtail_task() }
  }

  group "api" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "snoop" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      constraint {
        attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('hoover-snoop2')}"
        args = ["sh", "/local/startup.sh"]
        volumes = [
          ${hoover_snoop2_repo}
          "{% raw %}${meta.liquid_collections}{% endraw %}/${name}:/opt/hoover/collection",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/collections/${name}/blobs:/opt/hoover/snoop/blobs",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "snoop-${name}-api"
        }
      }
      env {
        SNOOP_COLLECTION_ROOT = "/opt/hoover/collection"
        SNOOP_TASK_PREFIX = "${name}"
        SNOOP_ES_INDEX = "${name}"
      }
      template {
        data = <<-EOF
        #!/bin/sh
        set -ex
        if [ -z "$SNOOP_ES_URL" ] || [ -z "$SNOOP_DB" ]; then
          echo "incomplete configuration!"
          sleep 5
          exit 1
        fi
        date
        ./manage.py migrate --noinput
        ./manage.py healthcheck

        date
        exec /runserver
        EOF
        env = false
        destination = "local/startup.sh"
      }
      env {
        SNOOP_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8765/_es"
        SNOOP_STATS_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8765/_es"
        SNOOP_STATS_ES_PREFIX = ".hoover-snoopstats-"
        SNOOP_TIKA_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8765/_tika/"
      }
      template {
        data = <<-EOF
        {{- if keyExists "liquid_debug" }}
          DEBUG = {{ key "liquid_debug" | toJSON }}
        {{- end }}
        {{- with secret "liquid/collections/${name}/snoop.django" }}
          SECRET_KEY = {{.Data.secret_key | toJSON }}
        {{- end }}
        {{- range service "snoop-${name}-pg" }}
          SNOOP_DB = "postgresql://snoop:
          {{- with secret "liquid/collections/${name}/snoop.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{.Address}}:{{.Port}}/snoop"
        {{- end }}

        {{- range service "snoop-${name}-rabbitmq" }}
          SNOOP_AMQP_URL = "amqp://{{.Address}}:{{.Port}}"
        {{- end }}
        SNOOP_HOSTNAME = "${name}.snoop.{{ key "liquid_domain" }}"
        {{- range service "zipkin" }}
          TRACING_URL = "http://{{.Address}}:{{.Port}}"
        {{- end }}
        EOF
        destination = "local/snoop.env"
        env = true
      }
      resources {
        memory = 400
        cpu = 200
        network {
          mbits = 1
          port "http" {}
        }
      }
      service {
        name = "snoop-${name}"
        port = "http"
        tags = ["snoop-/${name} strip=/${name} host=${name}.snoop.${liquid_domain}"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/collection/json"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["${name}.snoop.${liquid_domain}"]
          }
        }
      }
    }

    ${ promtail_task() }
  }
}
