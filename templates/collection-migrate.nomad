{% from '_lib.hcl' import migration_reschedule %}

job "collection-${name}-migrate" {
  datacenters = ["dc1"]
  type = "batch"

  ${ migration_reschedule() }

  group "snoop" {
    task "migrate" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-snoop2"
        args = ["./manage.py", "migrate"]
        volumes = [
          ${hoover_snoop2_repo}
          "${liquid_volumes}/gnupg:/opt/hoover/gnupg",
          "${liquid_collections}/${name}/data:/opt/hoover/snoop/collection",
          "${liquid_volumes}/collections/${name}/blobs:/opt/hoover/snoop/blobs",
        ]
        labels {
          liquid_task = "snoop-${name}-worker"
        }
      }
      env {
        SNOOP_COLLECTION_ROOT = "collection"
        SNOOP_TASK_PREFIX = "${name}"
        SNOOP_ES_INDEX = "${name}"
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
        memory = 500
      }
    }
  }
}
