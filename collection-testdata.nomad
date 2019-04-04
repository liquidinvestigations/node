job "collection-testdata" {
  datacenters = ["dc1"]
  type = "service"

  group "deps" {
    task "rabbitmq" {
      driver = "docker"
      config {
        image = "rabbitmq:3.7.3"
        volumes = [
          "__LIQUID_VOLUMES__/collection-testdata/rabbitmq/rabbitmq:/var/lib/rabbitmq",
        ]
        port_map {
          amqp = 5672
        }
        labels {
          liquid_task = "snoop-testdata-rabbitmq"
        }
      }
      resources {
        network {
          port "amqp" {}
        }
        memory = 250
      }
      service {
        name = "snoop-testdata-rabbitmq"
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
          liquid_task = "snoop-testdata-tika"
        }
      }
      resources {
        network {
          port "tika" {}
        }
      }
      service {
        name = "snoop-testdata-tika"
        port = "tika"
      }
    }

    task "pg" {
      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "__LIQUID_VOLUMES__/collection-testdata/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "snoop-testdata-pg"
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
        name = "snoop-testdata-pg"
        port = "pg"
      }
    }
  }

  group "workers" {
    count = 2

    task "snoop" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-snoop2:liquid-nomad"
        args = ["./manage.py", "runworkers"]
        volumes = [
          "__LIQUID_VOLUMES__/gnupg:/opt/hoover/gnupg",
          "__LIQUID_COLLECTIONS__/testdata/data:/opt/hoover/snoop/collection",
          "__LIQUID_VOLUMES__/collection-testdata/blobs/testdata:/opt/hoover/snoop/blobs",
        ]
        labels {
          liquid_task = "snoop-testdata-worker"
        }
      }
      env {
        SNOOP_COLLECTION_ROOT = "collection"
        SNOOP_TASK_PREFIX = "testdata"
        SNOOP_ES_INDEX = "testdata"
      }
      template {
        data = <<EOF
            {{- if keyExists "liquid_debug" }}
              DEBUG = {{ key "liquid_debug" }}
            {{- end }}
            SNOOP_DB = postgresql://snoop:snoop@
              {{- range service "snoop-testdata-pg" -}}
                {{ .Address }}:{{ .Port }}
              {{- end -}}
              /snoop
            SNOOP_ES_URL = http://
              {{- range service "hoover-es" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_TIKA_URL = http://
              {{- range service "snoop-testdata-tika" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_AMQP_URL = amqp://
              {{- range service "snoop-testdata-rabbitmq" -}}
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
          "__LIQUID_COLLECTIONS__/testdata/data:/opt/hoover/snoop/collection",
          "__LIQUID_VOLUMES__/collection-testdata/blobs/testdata:/opt/hoover/snoop/blobs",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "snoop-testdata-api"
        }
      }
      env {
        SECRET_KEY = "TODO random key"
        SNOOP_COLLECTION_ROOT = "collection"
        SNOOP_TASK_PREFIX = "testdata"
        SNOOP_ES_INDEX = "testdata"
      }
      template {
        data = <<EOF
            {{- if keyExists "liquid_debug" }}
              DEBUG = {{ key "liquid_debug" }}
            {{- end }}
            SNOOP_DB = postgresql://snoop:snoop@
              {{- range service "snoop-testdata-pg" -}}
                {{ .Address }}:{{ .Port }}
              {{- end -}}
              /snoop
            SNOOP_ES_URL = http://
              {{- range service "hoover-es" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_TIKA_URL = http://
              {{- range service "snoop-testdata-tika" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_AMQP_URL = amqp://
              {{- range service "snoop-testdata-rabbitmq" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_HOSTNAME = testdata.snoop.{{ key "liquid_domain" }}
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
        name = "snoop-testdata"
        port = "http"
      }
    }
  }
}
