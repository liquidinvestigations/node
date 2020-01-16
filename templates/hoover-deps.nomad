{% from '_lib.hcl' import authproxy_group, continuous_reschedule, set_pg_password_template, promtail_task with context -%}

{%- macro elasticsearch_docker_config(data_dir_name) %}
      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch:6.8.3"
        args = ["/bin/sh", "-c", "chown 1000:1000 /usr/share/elasticsearch/data && echo chown done && /usr/local/bin/docker-entrypoint.sh"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover/es/${data_dir_name}:/usr/share/elasticsearch/data",
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
      }
{%- endmacro %}

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
        check_restart {
          limit = 5
          grace = "180s"
        }
      }
    }

    ${ promtail_task() }
  }

  group "dask-scheduler" {
    ephemeral_disk {
      migrate = true
      size    = "500"
      sticky  = true
    }
    task "scheduler" {
      driver = "docker"
      config {
        image = "daskdev/dask:2.9.1"
        args = ["dask-scheduler", "--local-directory", "/local/data"]

        port_map {
          tcp = 8786
          http = 8787
        }
        labels {
          liquid_task = "dask-scheduler"
        }
      }
      env {
        EXTRA_CONDA_PACKAGES = "bokeh"
      }
      resources {
        memory = 400
        cpu = 200
        network {
          mbits = 1
          port "http" {}
          port "tcp" {}
        }
      }
      service {
        name = "dask-scheduler-ui"
        port = "http"
        check {
          name = "http"
          initial_status = "critical"
          path = "/"
          type = "http"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
      service {
        name = "dask-scheduler"
        port = "tcp"
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

  group "dask-worker" {
    ephemeral_disk {
      migrate = true
      size    = "500"
      sticky  = true
    }
    task "worker" {
      driver = "docker"

      config {
        image = "daskdev/dask:2.9.1"
        args = ["bash", "/local/startup.sh"]
        labels {
          liquid_task = "dask-worker"
        }
      }

      resources {
        memory = 1000
        cpu = 200
        network {
          mbits = 1
          port "dashboard" {}
          port "worker" {}
          port "nanny" {}
        }
      }

      env {
        "DASK_DISTRIBUTED__SCHEDULER__WORK_STEALING" = "True"
        "DASK_DISTRIBUTED__SCHEDULER__ALLOWED_FAILURES" = "5"

        HOST = "{% raw %}${attr.unique.network.ip-address}{% endraw %}"
        WORKER_PORT = "{% raw %}${NOMAD_HOST_PORT_worker}{% endraw %}"
        DASH_PORT = "{% raw %}${NOMAD_HOST_PORT_dashboard}{% endraw %}"
        NANNY_PORT = "{% raw %}${NOMAD_HOST_PORT_nanny}{% endraw %}"
        NTHREADS = "3"
      }

      template {
        data = <<-EOF
        #!/bin/bash
        set -ex
        dask-worker \
                --listen-address "tcp://0.0.0.0:$WORKER_PORT" \
                --contact-address "tcp://$HOST:$WORKER_PORT" \
                --dashboard-address "0.0.0.0:$DASH_PORT" \
                --nanny-port "$NANNY_PORT" \
                --nthreads "$NTHREADS" \
                --nprocs 1 \
                --memory-limit "1000M" \
                --local-directory "/local/data" \
                {{ range service "dask-scheduler" -}}
                        tcp://{{.Address}}:{{.Port}}
                {{- end }}
        EOF
        env = false
        destination = "local/startup.sh"
      }
      service {
        name = "dask-worker-ui"
        port = "dashboard"
        check {
          name = "http"
          initial_status = "critical"
          path = "/"
          type = "http"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
      service {
        name = "dask-worker"
        port = "worker"
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

  group "dask-notebook" {
    task "notebook" {
      driver = "docker"
      config {
        image = "daskdev/dask-notebook:2.9.1"

        port_map {
          http = 8888
        }
        labels {
          liquid_task = "dask-notebook"
        }
      }

      template {
        data = <<-EOF
        DASK_SCHEDULER_ADDRESS={{- range service "dask-scheduler" -}}tcp://{{.Address}}:{{.Port}}{{- end -}}
        EOF
        env = true
        destination = "local/env.sh"
      }

      resources {
        memory = 400
        cpu = 200
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "dask-notebook"
        port = "http"
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
        check_restart {
          limit = 5
          grace = "180s"
        }
      }
    }

    ${ promtail_task() }
  }
}
