job "collection-${collection_name}" {
  datacenters = ["dc1"]
  type = "service"

  group "deps" {
    task "rabbitmq" {
      driver = "docker"
      config {
        image = "rabbitmq:3.7.3"
        volumes = [
          "__LIQUID_VOLUMES__/collections/${collection_name}/rabbitmq/rabbitmq:/var/lib/rabbitmq",
        ]
        port_map {
          amqp = 5672
        }
        labels {
          liquid_task = "snoop-${collection_name}-rabbitmq"
        }
      }
      resources {
        network {
          port "amqp" {}
        }
        memory = 250
      }
      service {
        name = "snoop-${collection_name}-rabbitmq"
        port = "amqp"
      }
    }

    task "tika" {
      driver = "docker"
      config {
        image = "logicalspark/docker-tikaserver"
        port_map {
          http = 9998
        }
        labels {
          liquid_task = "snoop-${collection_name}-tika"
        }
      }
      resources {
        network {
          port "tika" {}
        }
      }
      service {
        name = "snoop-${collection_name}-tika"
        port = "tika"
      }
    }

    task "pg" {
      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "__LIQUID_VOLUMES__/collections/${collection_name}/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "snoop-${collection_name}-pg"
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
        network {
          port "pg" {}
        }
        memory = 100
      }
      service {
        name = "snoop-${collection_name}-pg"
        port = "pg"
      }
    }
  }

  group "workers" {
    count = $workers

    task "snoop" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-snoop2:liquid-nomad"
        args = ["./manage.py", "runworkers"]
        volumes = [
          "__LIQUID_VOLUMES__/gnupg:/opt/hoover/gnupg",
          "__LIQUID_COLLECTIONS__/${collection_name}/data:/opt/hoover/snoop/collection",
          "__LIQUID_VOLUMES__/collections/${collection_name}/blobs:/opt/hoover/snoop/blobs",
        ]
        labels {
          liquid_task = "snoop-${collection_name}-worker"
        }
      }
      env {
        SNOOP_COLLECTION_ROOT = "collection"
        SNOOP_TASK_PREFIX = "${collection_name}"
        SNOOP_ES_INDEX = "${collection_name}"
      }
      template {
        data = <<EOF
            {{- if keyExists "liquid_debug" }}
              DEBUG = {{ key "liquid_debug" }}
            {{- end }}
            SNOOP_DB = postgresql://snoop:snoop@
              {{- range service "snoop-${collection_name}-pg" -}}
                {{ .Address }}:{{ .Port }}
              {{- end -}}
              /snoop
            SNOOP_ES_URL = http://
              {{- range service "hoover-es" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_TIKA_URL = http://
              {{- range service "snoop-${collection_name}-tika" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_AMQP_URL = amqp://
              {{- range service "snoop-${collection_name}-rabbitmq" -}}
                {{ .Address }}:{{ .Port }}
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

  group "api" {
    task "snoop" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-snoop2:liquid-nomad"
        volumes = [
          "__LIQUID_VOLUMES__/gnupg:/opt/hoover/gnupg",
          "__LIQUID_COLLECTIONS__/${collection_name}/data:/opt/hoover/snoop/collection",
          "__LIQUID_VOLUMES__/collections/${collection_name}/blobs:/opt/hoover/snoop/blobs",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "snoop-${collection_name}-api"
        }
      }
      env {
        SECRET_KEY = "TODO random key"
        SNOOP_COLLECTION_ROOT = "collection"
        SNOOP_TASK_PREFIX = "${collection_name}"
        SNOOP_ES_INDEX = "${collection_name}"
      }
      template {
        data = <<EOF
            {{- if keyExists "liquid_debug" }}
              DEBUG = {{ key "liquid_debug" }}
            {{- end }}
            SNOOP_DB = postgresql://snoop:snoop@
              {{- range service "snoop-${collection_name}-pg" -}}
                {{ .Address }}:{{ .Port }}
              {{- end -}}
              /snoop
            SNOOP_ES_URL = http://
              {{- range service "hoover-es" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_TIKA_URL = http://
              {{- range service "snoop-${collection_name}-tika" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_AMQP_URL = amqp://
              {{- range service "snoop-${collection_name}-rabbitmq" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_HOSTNAME = ${collection_name}.snoop.{{ key "liquid_domain" }}
          EOF
        destination = "local/snoop.env"
        env = true
      }
      resources {
        memory = 200
        network {
          port "http" {}
        }
      }
      service {
        name = "snoop-${collection_name}"
        port = "http"
      }
    }
  }
}
