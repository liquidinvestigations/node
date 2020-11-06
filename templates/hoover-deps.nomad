{% from '_lib.hcl' import shutdown_delay, continuous_reschedule, set_pg_password_template, task_logs, group_disk with context -%}

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
        cluster.routing.allocation.disk.watermark.low = "97%"
        cluster.routing.allocation.disk.watermark.high = "98%"
        cluster.routing.allocation.disk.watermark.flood_stage = "99%"
        cluster.info.update.interval = "10m"

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
    ${ continuous_reschedule() }
    ${ group_disk() }

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

      ${ elasticsearch_docker_config('data') }

      ${ shutdown_delay() }

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
        cpu = 600
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
    ${ continuous_reschedule() }
    ${ group_disk() }
    count = ${config.elasticsearch_data_node_count}
    spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

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
        cpu = 500
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

  group "search-pg" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "search-pg" {
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
        image = "postgres:9.6"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "search-pg"
        }
        port_map {
          pg = 5432
        }
        # 128MB, the default postgresql shared_memory config
        shm_size = 134217728
        memory_hard_limit = 1200
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
        name = "search-pg"
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

    ${ continuous_reschedule() }
    ${ group_disk() }
    spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

    task "tika" {
      ${ task_logs() }

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
        memory_hard_limit = ${4 * config.tika_memory_limit}
      }

      resources {
        memory = ${config.tika_memory_limit}
        cpu = 500
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

  group "rabbitmq" {
    ${ continuous_reschedule() }
    ${ group_disk() }

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
        image = "rabbitmq:3.8.5-management-alpine"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/snoop/rabbitmq/3.8.5:/var/lib/rabbitmq",
          "local/conf:/etc/rabbitmq/rabbitmq.conf:ro",
          "local/plugins:/etc/rabbitmq/enabled_plugins:ro",
        ]
        port_map {
          amqp = 5672
          http = 15672
          prom = 15692
        }
        labels {
          liquid_task = "snoop-rabbitmq"
        }
        memory_hard_limit = ${2 * config.snoop_rabbitmq_memory_limit}
      }

      resources {
        memory = ${config.snoop_rabbitmq_memory_limit}
        cpu = 250
        network {
          mbits = 1
          port "amqp" {}
          port "http" {}
          port "prom" {}
        }
      }

      #env { RABBITMQ_CONFIG_FILE = "/local/rabbitmq" }

      template {
        destination = "local/conf"
        data = <<-EOF
          collect_statistics_interval = 16000
          management.path_prefix = /_rabbit
          management.cors.allow_origins.1 = *
          management.enable_queue_totals = true
          listeners.tcp.default = 5672
          management.tcp.port = 15672
          loopback_users.guest = false
          total_memory_available_override_value = ${config.snoop_rabbitmq_memory_limit * 1024 * 1024}
          EOF
      }

      template {
        destination = "local/plugins"
        data = <<-EOF
          [rabbitmq_prometheus,rabbitmq_management].
          EOF
      }

      service {
        name = "hoover-rabbitmq"
        port = "amqp"
      }

      service {
        name = "hoover-rabbitmq-prom"
        port = "prom"
        tags = ["fabio-/_rabbit_prom"]
      }

      service {
        name = "hoover-rabbitmq-http"
        port = "http"
        tags = ["fabio-/_rabbit"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/_rabbit/api/healthchecks/node"
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

  group "snoop-pg" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "snoop-pg" {
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
        image = "postgres:12"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/snoop/pg/data:/var/lib/postgresql/data",
          "local/conf:/etc/postgresql.conf",
        ]
        args = ["-c", "config_file=/etc/postgresql.conf"]
        labels {
          liquid_task = "snoop-pg"
        }
        port_map {
          pg = 5432
        }
        shm_size = ${int(config.snoop_postgres_memory_limit * 0.27) * 1024 * 1024}
        memory_hard_limit = ${2 * config.snoop_postgres_memory_limit}
      }

      template {
        destination = "local/conf"
        data = <<-EOF
          listen_addresses = '*'
          port = 5432                             # (change requires restart)
          max_connections = ${config.snoop_postgres_max_connections}  # (change requires restart)
          shared_buffers = ${int(config.snoop_postgres_memory_limit * 0.25)}MB  # min 128kB
          huge_pages = try                        # on, off, or try
          temp_buffers = 32MB                     # min 800kB
          max_prepared_transactions = 0          # zero disables the feature
          work_mem = 48MB                         # min 64kB
          maintenance_work_mem = 64MB             # min 1MB
          autovacuum_work_mem = -1                # min 1MB, or -1 to use maintenance_work_mem
          max_stack_depth = 4MB                  # min 100kB
          shared_memory_type = mmap              # the default is the first option
                                                  # supported by the operating system:
                                                  #   mmap
                                                  #   sysv
                                                  #   windows
                                                  # (change requires restart)
          dynamic_shared_memory_type = posix      # the default is the first option
                                                  # supported by the operating system:
                                                  #   posix
                                                  #   sysv
                                                  #   windows
                                                  #   mmap

          effective_io_concurrency = 3            # 1-1000; 0 disables prefetching
          max_worker_processes = 8                # (change requires restart)
          max_parallel_maintenance_workers = 3   # taken from max_parallel_workers
          #max_parallel_workers_per_gather = 2    # taken from max_parallel_workers

          wal_writer_delay = 300ms                # 1-10000 milliseconds
          wal_writer_flush_after = 4MB            # measured in pages, 0 disables
          checkpoint_timeout = 5min              # range 30s-1d
          max_wal_size = ${max(120, int(config.snoop_postgres_memory_limit * 0.1))}MB
          min_wal_size = 80MB
          #checkpoint_completion_target = 0.5     # checkpoint target duration, 0.0 - 1.0
          #checkpoint_flush_after = 256kB         # measured in pages, 0 disables
          checkpoint_warning = 20s               # 0 disables
          log_timezone = 'Etc/UTC'
          cluster_name = 'snoop'                  # added to process titles if nonempty
          datestyle = 'iso, mdy'
          #intervalstyle = 'postgres'
          timezone = 'Etc/UTC'
          lc_messages = 'en_US.utf8'                      # locale for system error message
          lc_monetary = 'en_US.utf8'                      # locale for monetary formatting
          lc_numeric = 'en_US.utf8'                       # locale for number formatting
          lc_time = 'en_US.utf8'                          # locale for time formatting
          default_text_search_config = 'pg_catalog.english'

          effective_cache_size = ${int(config.snoop_postgres_memory_limit * 0.5)}MB
          EOF
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
        cpu = 600
        memory = ${config.snoop_postgres_memory_limit}
        network {
          mbits = 1
          port "pg" {}
        }
      }

      service {
        name = "snoop-pg"
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


  {% if not config.hoover_ui_override_server %}
  group "hoover-ui" {
    ${ group_disk() }

    task "hoover-ui" {
      leader = true

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('hoover-ui')}"
        volumes = [
          ${hoover_ui_src_repo}
          ${hoover_ui_pages_repo}
          ${hoover_ui_styles_repo}
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover-ui/build:/opt/hoover/ui/build",
        ]
        port_map {
          http = 8000
        }
        labels {
          liquid_task = "hoover-ui"
        }
        args = ["sh", "/local/startup.sh"]
        memory_hard_limit = 3000
      }

      template {
        data = <<-EOF
        #!/bin/sh
        set -ex
        cp -v /local/.env.local .

        {% if config.liquid_debug %}
          exec npm run prod # dev
        {% else %}
          exec npm run prod
        {% endif %}
        EOF
        env = false
        destination = "local/startup.sh"
      }

      template {
        data = <<-EOF
          NEXT_PUBLIC_HOOVER_HYPOTHESIS_URL="${config.liquid_http_protocol}://hypothesis.${config.liquid_domain}/embed.js"
        EOF
        env = true
        destination = "local/.env.local"
      }

      resources {
        memory = 900
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "hoover-ui"
        port = "http"
        tags = ["fabio-/hoover-ui strip=/hoover-ui"]
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
  {% endif %}
}
