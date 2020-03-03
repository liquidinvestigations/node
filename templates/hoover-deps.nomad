{% from '_lib.hcl' import authproxy_group, continuous_reschedule, set_pg_password_template with context -%}

{%- macro elasticsearch_docker_config(data_dir_name) %}
      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch:6.8.3"
        args = ["/bin/sh", "-c", "chown 1000:1000 /usr/share/elasticsearch/data /es_repo && echo chown done && /usr/local/bin/docker-entrypoint.sh"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover/es/${data_dir_name}:/usr/share/elasticsearch/data",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover/es/repo:/es_repo",
        ]
        port_map {
          http = 9200
          transport = 9300
        }
        labels {
          liquid_task = "hoover-es"
        }
        ulimit {
          memlock = "-1"
          nofile = "65536"
          nproc = "8192"
        }
      }

      env {
        xpack.license.self_generated.type = "basic"
        xpack.monitoring.collection.enabled = "true"
        xpack.monitoring.collection.interval = "30s"
        xpack.monitoring.collection.cluster.stats.timeout = "30s"
        xpack.monitoring.collection.node.stats.timeout = "30s"
        xpack.monitoring.collection.index.stats.timeout = "30s"
        xpack.monitoring.collection.index.recovery.timeout = "30s"
        xpack.monitoring.history.duration = "32d"
        path.repo = "/es_repo"
      }
{%- endmacro %}

job "hoover-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

  group "es-master" {
    task "es" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      ${ elasticsearch_docker_config('data') }
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
        tags = ["fabio-/_es strip=/_es"]
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
      ${elasticsearch_docker_config('data-${NOMAD_ALLOC_INDEX}') }
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
        tags = ["fabio-/_es strip=/_es"]
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
  }

  group "tika" {
    count = ${config.tika_count}

    task "tika" {
      driver = "docker"
      config {
        image = "logicalspark/docker-tikaserver:1.22"
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

      env {
        TIKA_CONFIG = "/local/tika.xml"
      }

      template {
        data = <<-EOF
          <?xml version="1.0" encoding="UTF-8"?>
          <properties>
            <parsers>
                <parser class="org.apache.tika.parser.DefaultParser">
                    <parser-exclude class="org.apache.tika.parser.ocr.TesseractOCRParser"/>
                </parser>
            </parsers>
          </properties>
          EOF
        destination = "local/tika.xml"
      }

      service {
        name = "hoover-tika"
        port = "tika"
        tags = ["fabio-/_tika strip=/_tika"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/version"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
        check_restart {
          limit = 5
          grace = "180s"
        }
      }
    }
  }

  {% if config.snoop_workers %}
  group "queue" {

    task "rabbitmq" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "rabbitmq:3.8.2-management-alpine"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/snoop/rabbitmq/rabbitmq:/var/lib/rabbitmq",
        ]
        port_map {
          amqp = 5672
          http = 15672
          clustering = 25672
        }
        labels {
          liquid_task = "snoop-rabbitmq"
        }
      }

      template {
        data = <<-EOF
          management.path_prefix = /_rabbit
          management.cors.allow_origins.1 = *
          EOF
        destination = "/etc/rabbitmq/rabbitmq.conf"
      }

      resources {
        memory = ${config.snoop_rabbitmq_memory_limit}
        cpu = 150
        network {
          mbits = 1
          port "amqp" {}
          port "http" {}
        }
      }
      service {
        name = "hoover-rabbitmq"
        port = "amqp"
      }

      service {
        name = "hoover-rabbitmq-http"
        port = "http"
        tags = ["fabio-/_rabbit strip=/_rabbit"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/api/healthchecks/node"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            # guest:guest
            Authorization = ["Basic Z3Vlc3Q6Z3Vlc3Q="]
          }
        }
      }
    }
  }
  {% endif %}

  group "snoop-db" {

    ${ continuous_reschedule() }

    task "pg" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "postgres:12.2"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/snoop/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "snoop-pg"
        }
        port_map {
          pg = 5432
        }
      }
      template {
        data = <<EOF
          POSTGRES_USER = "snoop"
          POSTGRES_DATABASE = "snoop"
          {{- with secret "liquid/hoover/snoop.postgres" }}
            POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/postgres.env"
        env = true
      }
      ${ set_pg_password_template('snoop') }
      resources {
        cpu = 200
        memory = 300
        network {
          mbits = 1
          port "pg" {}
        }
      }
      service {
        name = "hoover-snoop-pg"
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
}
