{% from '_lib.hcl' import continuous_reschedule -%}

job "collection-${name}" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  group "queue" {
    task "rabbitmq" {
      driver = "docker"
      config {
        image = "rabbitmq:3.7.3"
        volumes = [
          "${liquid_volumes}/collections/${name}/rabbitmq/rabbitmq:/var/lib/rabbitmq",
        ]
        port_map {
          amqp = 5672
        }
        labels {
          liquid_task = "snoop-${name}-rabbitmq"
        }
      }
      resources {
        memory = 700
        cpu = 150
        network {
          port "amqp" {}
        }
      }
      service {
        name = "snoop-${name}-rabbitmq"
        port = "amqp"
        check {
          name = "rabbitmq alive on tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "tika" {
    task "tika" {
      driver = "docker"
      config {
        image = "logicalspark/docker-tikaserver"
        port_map {
          tika = 9998
        }
        labels {
          liquid_task = "snoop-${name}-tika"
        }
      }
      resources {
        memory = 800
        cpu = 200
        network {
          port "tika" {}
        }
      }
      service {
        name = "snoop-${name}-tika"
        port = "tika"
        check {
          name = "tika alive on http"
          initial_status = "critical"
          type = "http"
          path = "/version"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "db" {
    ${ continuous_reschedule() }

    task "pg" {
      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "${liquid_volumes}/collections/${name}/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "snoop-${name}-pg"
        }
        port_map {
          pg = 5432
        }
      }
      env {
        POSTGRES_USER = "snoop"
        POSTGRES_DATABASE = "snoop"
      }
      resources {
        cpu = 400
        memory = 400
        network {
          port "pg" {}
        }
      }
      service {
        name = "snoop-${name}-pg"
        port = "pg"
        check {
          name = "postgres alive on tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "workers" {
    count = ${workers}

    task "snoop" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-snoop2"
        args = ["sh", "/local/startup.sh"]
        volumes = [
          ${hoover_snoop2_repo}
          "${liquid_volumes}/gnupg:/opt/hoover/gnupg",
          "${liquid_collections}/${name}:/opt/hoover/collection",
          "${liquid_volumes}/collections/${name}/blobs:/opt/hoover/snoop/blobs",
        ]
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
        if [ -z "$SNOOP_DB" ] \
                || [ -z "$SNOOP_TIKA_URL" ] \
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
      template {
        data = <<EOF
        {{- if keyExists "liquid_debug" }}
          DEBUG = {{key "liquid_debug"}}
        {{- end }}
        {{- range service "snoop-${name}-pg" }}
          SNOOP_DB = postgresql://snoop:snoop@{{.Address}}:{{.Port}}/snoop
        {{- end }}
        {{- range service "hoover-es" }}
          SNOOP_ES_URL = http://{{.Address}}:{{.Port}}
        {{- end }}
        {{- range service "snoop-${name}-tika" }}
          SNOOP_TIKA_URL = http://{{.Address}}:{{.Port}}
        {{- end }}
        {{- range service "snoop-${name}-rabbitmq" }}
          SNOOP_AMQP_URL = amqp://{{.Address}}:{{.Port}}
        {{- end }}
        {{ range service "zipkin" }}
          TRACING_URL = http://{{.Address}}:{{.Port}}
        {{- end }}
        EOF
        destination = "local/snoop.env"
        env = true
      }
      resources {
        memory = 400
      }
    }
  }

  group "api" {
    ${ continuous_reschedule() }

    task "snoop" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-snoop2"
        args = ["sh", "/local/startup.sh"]
        volumes = [
          ${hoover_snoop2_repo}
          "${liquid_volumes}/gnupg:/opt/hoover/gnupg",
          "${liquid_collections}/${name}:/opt/hoover/collection",
          "${liquid_volumes}/collections/${name}/blobs:/opt/hoover/snoop/blobs",
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
        if [ -z "$SNOOP_DB" ] \
                || [ -z "$SNOOP_TIKA_URL" ] \
                || [ -z "$SNOOP_ES_URL" ] \
                || [ -z "$SNOOP_AMQP_URL" ]; then
          echo "incomplete configuration!"
          sleep 5
          exit 1
        fi
        exec /runserver
        EOF
        env = false
        destination = "local/startup.sh"
      }
      template {
        data = <<-EOF
        {{- if keyExists "liquid_debug" }}
          DEBUG = {{ key "liquid_debug" }}
        {{- end }}
        {{- with secret "liquid/collections/${name}/snoop.django" }}
          SECRET_KEY = {{.Data.secret_key}}
        {{- end }}
        {{- range service "snoop-${name}-pg" }}
          SNOOP_DB = postgresql://snoop:snoop@{{.Address}}:{{.Port}}/snoop
        {{- end }}
        {{- range service "hoover-es" }}
          SNOOP_ES_URL = http://{{.Address}}:{{.Port}}
        {{- end }}
        {{- range service "snoop-${name}-tika" }}
          SNOOP_TIKA_URL = http://{{.Address}}:{{.Port}}
        {{- end }}
        {{- range service "snoop-${name}-rabbitmq" }}
          SNOOP_AMQP_URL = amqp://{{.Address}}:{{.Port}}
        {{- end }}
        SNOOP_HOSTNAME = ${name}.snoop.{{ key "liquid_domain" }}
        {{- range service "zipkin" }}
          TRACING_URL = http://{{.Address}}:{{.Port}}
        {{- end }}
        EOF
        destination = "local/snoop.env"
        env = true
      }
      resources {
        memory = 400
        cpu = 200
        network {
          port "http" {}
        }
      }
      service {
        name = "snoop-${name}"
        port = "http"
        check {
          name = "snoop alive on http"
          initial_status = "critical"
          type = "http"
          path = "/collection/json"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["${name}.snoop.${liquid_domain}"]
          }
        }
        check {
          name = "snoop healthcheck script"
          initial_status = "warning"
          type = "script"
          command = "python"
          args = ["manage.py", "healthcheck"]
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
