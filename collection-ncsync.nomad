job "collection-ncsync" {
  datacenters = ["dc1"]
  type = "service"
  
  group "deps" {
    task "rabbitmq" {
      driver = "docker"
      config {
        image = "rabbitmq:3.7.3"
        volumes = [
          "__LIQUID_VOLUMES__/collection-ncsync/rabbitmq/rabbitmq:/var/lib/rabbitmq",
        ]
        port_map {
          amqp = 5672
        }
        labels {
          liquid_task = "snoop-ncsync-rabbitmq"
        }
      }
      resources {
        network {
          port "amqp" {}
        }
        memory = 250
      }
      service {
        name = "snoop-ncsync-rabbitmq"
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
          liquid_task = "snoop-ncsync-tika"
        }
      }
      resources {
        network {
          port "tika" {}
        }
      }
      service {
        name = "snoop-ncsync-tika"
        port = "tika"
      }
    }

    task "pg" {
      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "__LIQUID_VOLUMES__/collection-ncsync/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "snoop-ncsync-pg"
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
        name = "snoop-ncsync-pg"
        port = "pg"
      }
    }
  }
  
  group "workers" {
    count = 2

    task "snoop" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-snoop2"
        args = ["./manage.py", "runworkers" ,"-s"]
        volumes = [
          "__LIQUID_VOLUMES__/gnupg:/opt/hoover/gnupg",
          "__LIQUID_COLLECTIONS__/ncsync:/opt/hoover/snoop/collection",
          "__LIQUID_VOLUMES__/collection-ncsync/blobs/ncsync:/opt/hoover/snoop/blobs",
        ]
        labels {
          liquid_task = "snoop-ncsync-worker"
        }
      }
      env {
        SNOOP_COLLECTION_ROOT = "collection"
        SNOOP_TASK_PREFIX = "ncsync"
        SNOOP_ES_INDEX = "ncsync"
      }
      template {
        data = <<EOF
            {{- if keyExists "liquid_debug" }}
              DEBUG = {{ key "liquid_debug" }}
            {{- end }}
            SNOOP_DB = postgresql://snoop:snoop@
              {{- range service "snoop-ncsync-pg" -}}
                {{ .Address }}:{{ .Port }}
              {{- end -}}
              /snoop
            SNOOP_ES_URL = http://
              {{- range service "hoover-es" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_TIKA_URL = http://
              {{- range service "snoop-ncsync-tika" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_AMQP_URL = amqp://
              {{- range service "snoop-ncsync-rabbitmq" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
          EOF
        destination = "local/snoop.env"
        env = true
      }
      resources {
        memory = 512
      }
    }
  }
  
  group "api" {
    task "snoop" {
      driver = "docker"
      config {
        image = "liquidinvestigations/hoover-snoop2"
        volumes = [
          "__LIQUID_VOLUMES__/gnupg:/opt/hoover/gnupg",
          "__LIQUID_COLLECTIONS__/ncsync:/opt/hoover/snoop/collection",
          "__LIQUID_VOLUMES__/collection-ncsync/blobs/ncsync:/opt/hoover/snoop/blobs",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "snoop-ncsync-api"
        }
      }
      env {
        SECRET_KEY = "TODO random key"
        SNOOP_COLLECTION_ROOT = "collection"
        SNOOP_TASK_PREFIX = "ncsync"
        SNOOP_ES_INDEX = "ncsync"
      }
      template {
        data = <<EOF
            {{- if keyExists "liquid_debug" }}
              DEBUG = {{ key "liquid_debug" }}
            {{- end }}
            SNOOP_DB = postgresql://snoop:snoop@
              {{- range service "snoop-ncsync-pg" -}}
                {{ .Address }}:{{ .Port }}
              {{- end -}}
              /snoop
            SNOOP_ES_URL = http://
              {{- range service "hoover-es" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_TIKA_URL = http://
              {{- range service "snoop-ncsync-tika" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_AMQP_URL = amqp://
              {{- range service "snoop-ncsync-rabbitmq" -}}
                {{ .Address }}:{{ .Port }}
              {{- end }}
            SNOOP_HOSTNAME = ncsync.snoop.{{ key "liquid_domain" }}
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
        name = "snoop-ncsync"
        port = "http"
      }
    }
  }
}
