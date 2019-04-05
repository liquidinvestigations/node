job "collection-${name}" {
  datacenters = ["dc1"]
  type = "service"

  group "deps" {
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
        network {
          port "amqp" {}
        }
        memory = 250
      }
      service {
        name = "snoop-${name}-rabbitmq"
        port = "amqp"
      }
    }

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
        network {
          port "tika" {}
        }
      }
      service {
        name = "snoop-${name}-tika"
        port = "tika"
      }
    }

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
        network {
          port "pg" {}
        }
        memory = 100
      }
      service {
        name = "snoop-${name}-pg"
        port = "pg"
      }
    }
  }

  group "workers" {
    count = $workers

    task "snoop" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-snoop2"
        args = ["./manage.py", "runworkers"]
        volumes = [
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
              DEBUG = {{ key "liquid_debug" }}
            {{- end }}
            SNOOP_DB = postgresql://snoop:snoop@
              {{- range service "snoop-${name}-pg" -}}
                {{ .Address }}:{{ .Port }}
              {{- end -}}
              /snoop
            SNOOP_ES_URL = http://
              {{- range service "hoover-es" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_TIKA_URL = http://
              {{- range service "snoop-${name}-tika" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_AMQP_URL = amqp://
              {{- range service "snoop-${name}-rabbitmq" -}}
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
        image = "liquidinvestigations/hoover-snoop2"
        volumes = [
          "${liquid_volumes}/gnupg:/opt/hoover/gnupg",
          "${liquid_collections}/${name}/data:/opt/hoover/snoop/collection",
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
        SECRET_KEY = "TODO random key"
        SNOOP_COLLECTION_ROOT = "collection"
        SNOOP_TASK_PREFIX = "${name}"
        SNOOP_ES_INDEX = "${name}"
      }
      template {
        data = <<EOF
            {{- if keyExists "liquid_debug" }}
              DEBUG = {{ key "liquid_debug" }}
            {{- end }}
            SNOOP_DB = postgresql://snoop:snoop@
              {{- range service "snoop-${name}-pg" -}}
                {{ .Address }}:{{ .Port }}
              {{- end -}}
              /snoop
            SNOOP_ES_URL = http://
              {{- range service "hoover-es" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_TIKA_URL = http://
              {{- range service "snoop-${name}-tika" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_AMQP_URL = amqp://
              {{- range service "snoop-${name}-rabbitmq" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_HOSTNAME = ${name}.snoop.{{ key "liquid_domain" }}
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
        name = "snoop-${name}"
        port = "http"
      }
    }
  }
}
