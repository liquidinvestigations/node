{% from '_lib.hcl' import authproxy_group, continuous_reschedule, set_pg_password_template, promtail_task with context -%}

job "hoover-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  group "index" {
    task "es" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch-oss:6.2.4"
        args = ["/bin/sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data && echo chown done && /usr/local/bin/docker-entrypoint.sh"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover/es/data:/usr/share/elasticsearch/data",
        ]
        port_map {
          es = 9200
        }
        labels {
          liquid_task = "hoover-es"
        }
      }
      env {
        cluster.name = "hoover"
        ES_JAVA_OPTS = "-Xms${config.elasticsearch_heap_size}m -Xmx${config.elasticsearch_heap_size}m"
      }
      resources {
        memory = ${config.elasticsearch_memory_limit}
        network {
          mbits = 1
          port "es" {}
        }
      }
      service {
        name = "hoover-es"
        port = "es"
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

    ${ promtail_task() }
  }

  group "db" {
    ${ continuous_reschedule() }

    task "pg" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "postgres:9.6"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "hoover-pg"
        }
        port_map {
          pg = 5432
        }
      }
      template {
        data = <<EOF
          POSTGRES_USER = "search"
          POSTGRES_DATABASE = "search"
          {{- with secret "liquid/hoover/search.postgres" }}
            POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/postgres.env"
        env = true
      }
      ${ set_pg_password_template('search') }
      resources {
        memory = 350
        network {
          mbits = 1
          port "pg" {}
        }
      }
      service {
        name = "hoover-pg"
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

    ${ promtail_task() }
  }

  group "tika" {
    task "tika" {
      driver = "docker"
      config {
        image = "logicalspark/docker-tikaserver:1.20"
        port_map {
          tika = 9998
        }
        labels {
          liquid_task = "hoover-tika"
        }
      }
      resources {
        memory = ${config.tika_memory_limit}
        cpu = 200
        network {
          mbits = 1
          port "tika" {}
        }
      }
      service {
        name = "hoover-tika"
        port = "tika"
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/version"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    ${ promtail_task() }
  }
}
