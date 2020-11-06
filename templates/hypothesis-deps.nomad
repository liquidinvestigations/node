{% from '_lib.hcl' import shutdown_delay, authproxy_group_old, task_logs, group_disk, continuous_reschedule with context -%}

job "hypothesis-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  group "pg" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "pg" {
      ${ task_logs() }
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = 100
      }

      driver = "docker"

      ${ shutdown_delay() }

      config {
        image = "postgres:9.4-alpine"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hypothesis/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "hypothesis-pg"
        }
        port_map {
          pg = 5432
        }
        # 128MB, the default postgresql shared_memory config
        shm_size = 134217728
        memory_hard_limit = 2000
      }

      template {
        data = <<-EOF
          POSTGRES_USER = "hypothesis"
          POSTGRES_DATABASE = "hypothesis"
          {{- with secret "liquid/hypothesis/hypothesis.postgres" }}
            POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
          EOF
        destination = "local/postgres.env"
        env = true
      }

      resources {
        memory = 350
        network {
          mbits = 1
          port "pg" {}
        }
      }

      service {
        name = "hypothesis-pg"
        port = "pg"
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "es" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "es" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = 100
      }

      driver = "docker"

      ${ shutdown_delay() }

      config {
        image = "hypothesis/elasticsearch:latest"
        args = ["/bin/sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data && chown 1000:1000 /usr/share/elasticsearch/data /es_repo && echo chown done && /usr/local/bin/docker-entrypoint.sh"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hypothesis/es/data:/usr/share/elasticsearch/data",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hypothesis/es/repo:/es_repo",
        ]
        port_map {
          es = 9200
        }
        labels {
          liquid_task = "hypothesis-es"
        }
        memory_hard_limit = 1500
      }

      env {
        discovery.type = "single-node"
        ES_JAVA_OPTS = "-Xms600m -Xmx600m"
        path.repo = "/es_repo"
      }

      resources {
        memory = 900
        network {
          mbits = 1
          port "es" {}
        }
      }

      env {
        cluster.routing.allocation.disk.watermark.low = "97%"
        cluster.routing.allocation.disk.watermark.high = "98%"
        cluster.routing.allocation.disk.watermark.flood_stage = "99%"
        cluster.info.update.interval = "10m"
      }

      service {
        name = "hypothesis-es"
        port = "es"
        tags = ["fabio-/_h_es strip=/_h_es"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/_cluster/health"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "rabbitmq" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "rabbitmq" {
      ${ task_logs() }
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = 100
      }

      driver = "docker"

      ${ shutdown_delay() }

      config {
        image = "rabbitmq:3.6-management-alpine"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hypothesis/rabbitmq/rabbitmq:/var/lib/rabbitmq",
        ]
        port_map {
          amqp = 5672
          management = 15672
        }
        labels {
          liquid_task = "hypothesis-rabbitmq"
        }
        memory_hard_limit = 600
      }

      resources {
        memory = 300
        cpu = 150
        network {
          mbits = 1
          port "amqp" {}
        }
      }

      service {
        name = "hypothesis-rabbitmq"
        port = "amqp"
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
