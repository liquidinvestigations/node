{% from '_lib.hcl' import authproxy_group, continuous_reschedule, set_pg_password_template, promtail_task with context -%}

job "hoover-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  group "es-master" {
    task "es" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch-oss:6.8.3"
        args = ["/bin/sh", "-c", "chown 1000:1000 /usr/share/elasticsearch/data && echo chown done && /usr/local/bin/docker-entrypoint.sh"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover/es/data:/usr/share/elasticsearch/data",
        ]
        port_map {
          http = 9200
          transport = 9300
        }
        labels {
          liquid_task = "hoover-es"
        }
      }
      env {
        cluster.name = "hoover"
        node.name = "master"

        http.port = "9200"
        http.publish_port = "{% raw %}${NOMAD_HOST_PORT_http}{% endraw %}"
        http.bind_host = "0.0.0.0"
        http.publish_host = "{% raw %}${attr.unique.network.ip-address}{% endraw %}"

        transport.port = "9300"
        transport.publish_port = "{% raw %}${NOMAD_HOST_PORT_transport}{% endraw %}"
        transport.bind_host = "0.0.0.0"
        transport.publish_host = "{% raw %}${attr.unique.network.ip-address}{% endraw %}"

        ES_JAVA_OPTS = "-Xms${config.elasticsearch_heap_size}m -Xmx${config.elasticsearch_heap_size}m -XX:+UnlockDiagnosticVMOptions"
      }
      resources {
        memory = ${config.elasticsearch_memory_limit}
        network {
          mbits = 1
          port "http" {}
          port "transport" {}
        }
      }
      service {
        name = "hoover-es-master"
        port = "http"
        tags = ["snoop-/_es strip=/_es"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/_cluster/health"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
      service {
        name = "hoover-es-master-transport"
        port = "transport"
        check {
          name = "transport"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    ${ promtail_task() }
  }

  {% if config.elasticsearch_data_node_count %}
  group "es-data" {
    count = ${config.elasticsearch_data_node_count}

    task "es" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch-oss:6.8.3"
        args = ["/bin/sh", "-c", "chown 1000:1000 /usr/share/elasticsearch/data && echo chown done && env && /usr/local/bin/docker-entrypoint.sh"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover/es/data-{% raw %}${NOMAD_ALLOC_INDEX}{% endraw %}:/usr/share/elasticsearch/data",
        ]
        port_map {
          http = 9200
          transport = 9300
        }
        labels {
          liquid_task = "hoover-es"
        }
      }
      env {
        node.master = "false"
        cluster.name = "hoover"
        node.name = "data-{% raw %}${NOMAD_ALLOC_INDEX}{% endraw %}"

        http.port = "9200"
        http.publish_port = "{% raw %}${NOMAD_HOST_PORT_http}{% endraw %}"
        http.bind_host = "0.0.0.0"
        http.publish_host = "{% raw %}${attr.unique.network.ip-address}{% endraw %}"

        transport.port = "9300"
        transport.publish_port = "{% raw %}${NOMAD_HOST_PORT_transport}{% endraw %}"
        transport.bind_host = "0.0.0.0"
        transport.publish_host = "{% raw %}${attr.unique.network.ip-address}{% endraw %}"

        ES_JAVA_OPTS = "-Xms${config.elasticsearch_heap_size}m -Xmx${config.elasticsearch_heap_size}m -XX:+UnlockDiagnosticVMOptions"
      }
      template {
        data = <<-EOF
          discovery.zen.ping.unicast.hosts = {{- range service "hoover-es-master-transport" -}}"{{.Address}}:{{.Port}}"{{- end -}}
          EOF
        destination = "local/es-master.env"
        env = true
      }
      resources {
        memory = ${config.elasticsearch_memory_limit}
        network {
          mbits = 1
          port "http" {}
          port "transport" {}
        }
      }
      service {
        name = "hoover-es-data"
        port = "http"
        tags = ["snoop-/_es strip=/_es"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/_cluster/health"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
      service {
        name = "hoover-es-data-transport"
        port = "transport"
        check {
          name = "transport"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    ${ promtail_task() }
  }
  {% endif %}

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
    count = ${config.tika_count}

    task "tika" {
      driver = "docker"
      config {
        image = "logicalspark/docker-tikaserver:1.20"
        args = ["-spawnChild", "-maxFiles", "1000"]
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
        tags = ["snoop-/_tika strip=/_tika"]
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
