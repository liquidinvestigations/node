{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "collection-${name}-migrate" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 45

  group "snoop" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "migrate" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('liquidinvestigations/hoover-snoop2')}"
        args = ["sh", "/local/migrate.sh"]
        volumes = [
          ${hoover_snoop2_repo}
          "${liquid_volumes}/gnupg:/opt/hoover/gnupg",
          "${liquid_collections}/${name}/data:/opt/hoover/snoop/collection",
          "${liquid_volumes}/collections/${name}/blobs:/opt/hoover/snoop/blobs",
        ]
        labels {
          liquid_task = "snoop-${name}-migrate"
        }
      }
      env {
        SNOOP_COLLECTION_ROOT = "collection"
        SNOOP_TASK_PREFIX = "${name}"
        SNOOP_ES_INDEX = "${name}"
        TIMESTAMP = "${config.timestamp}"
      }
      template {
        data = <<-EOF
        #!/bin/sh
        set -ex
        pwd
        date
        ./manage.py migrate --noinput
        ./manage.py healthcheck
        EOF
        destination = "local/migrate.sh"
      }
      template {
        data = <<-EOF
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
        memory = 200
      }
    }
  }
}
