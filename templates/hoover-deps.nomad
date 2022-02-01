{% from '_lib.hcl' import shutdown_delay, continuous_reschedule, set_pg_password_template, task_logs, group_disk with context -%}

{%- macro elasticsearch_docker_config(data_dir_name) %}
      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch:6.8.15"
        args = ["/bin/sh", "-c", "chown 1000:1000 /usr/share/elasticsearch/data /es_repo && echo chown done && exec /usr/local/bin/docker-entrypoint.sh"]
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

        http.max_content_length = "1900mb"

        xpack.license.self_generated.type = "basic"
        xpack.monitoring.collection.enabled = "true"
        xpack.monitoring.collection.interval = "30s"
        xpack.monitoring.collection.cluster.stats.timeout = "30s"
        xpack.monitoring.collection.node.stats.timeout = "30s"
        xpack.monitoring.collection.index.stats.timeout = "30s"
        xpack.monitoring.collection.index.recovery.timeout = "30s"
        xpack.monitoring.history.duration = "32d"

        path.repo = "/es_repo"

        ES_JAVA_OPTS = "-Xms${config.elasticsearch_heap_size}m -Xmx${config.elasticsearch_heap_size}m -XX:+UseG1GC -XX:MaxGCPauseMillis=300 -XX:G1HeapRegionSize=16m -verbose:gc"
        LIQUID_HOOVER_ES_DATA_NODE_COUNT = "${config.elasticsearch_data_node_count}"
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
      }

      resources {
        cpu = 400
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
          name = "http-cluster-status"
          initial_status = "critical"
          type = "http"
          path = "/_cluster/health?timeout=${check_timeout}&wait_for_nodes=ge(${config.elasticsearch_data_node_count})"
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
      }
      template {
        data = <<-EOF
          discovery.zen.ping.unicast.hosts = {{- range service "hoover-es-master-transport" -}}"{{.Address}}:{{.Port}}"{{- end -}}
          EOF
        destination = "local/es-master.env"
        env = true
      }
      resources {
        cpu = 400
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
        image = "postgres:13"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover/search-pg-13/data:/var/lib/postgresql/data",
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
          name = "pg_isready"
          type = "script"
          command = "/bin/sh"
          args = ["-c", "pg_isready"]
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
        cpu = 400
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
          grace = "480s"
        }
      }
    }
  }

  {% if config.snoop_pdf_preview_enabled %}
  group "pdf-preview" {
    count = ${config.snoop_pdf_preview_count}

    ${ continuous_reschedule() }
    ${ group_disk() }

    task "pdf-preview" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('pdf-preview')}"
        port_map {
          pdf_preview = 3000
        }
        labels {
          liquid_task = "hoover-pdf-preview"
        }
        memory_hard_limit = ${4 * config.snoop_pdf_preview_memory_limit}
      }

      resources {
        memory = ${config.snoop_pdf_preview_memory_limit}
        cpu = 100
        network {
          mbits = 1
          port "pdf_preview" {}
        }
      }

      service {
        name = "hoover-pdf-preview"
        port = "pdf_preview"
        tags = ["fabio-/_pdf-preview strip=/_pdf-preview"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/ping"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
  {% endif %}

  {% if config.snoop_thumbnail_generator_enabled %}
    group "thumbnail-generator" {
      count = ${config.snoop_thumbnail_generator_count}
  
      ${ continuous_reschedule() }
      ${ group_disk() }
  
      task "thumbnail-generator" {
        ${ task_logs() }
        user = "root"
  
        driver = "docker"
        config {
          image = "${config.image('thumbnail-generator')}"
          port_map {
            thumbnail = 8000
          }
          labels {
            liquid_task = "hoover-thumbnail-generator"
          }
          memory_hard_limit = ${4 * config.snoop_thumbnail_generator_memory_limit}
          mounts = [ 
            {
              type = "tmpfs"
              target = "/tmp"
              readonly = false
              tmpfs_options {
                # set size here if you want
              }
            }
          ]
        }
  
        resources {
          memory = ${config.snoop_thumbnail_generator_memory_limit}
          cpu = 500
          network {
            port "thumbnail" {}
            mbits = 1
          }
        }
  
        env {
          WEB_CONCURRENCY = 4
        }
  
        service {
          name = "hoover-thumbnail-generator"
          port = "thumbnail"
          tags = ["fabio-/_thumbnail-generator strip=/_thumbnail-generator"]
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
            grace = "60s"
          }
        }
      }
    }
    {% endif %}

  {% if config.snoop_image_classification_classify_images_enabled or config.snoop_image_classification_object_detection_enabled %}
  group "image-classification" {
    count = ${config.snoop_image_classification_count}

    ${ continuous_reschedule() }
    ${ group_disk() }

    task "image-classification" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('image-classification')}"
        port_map {
          image_classification = 5001
        }
        labels {
          liquid_task = "hoover-image-classification"
        }
        memory_hard_limit = ${4 * config.snoop_image_classification_memory_limit}
      }

      resources {
        memory = ${config.snoop_image_classification_memory_limit}
        cpu = 100
        network {
          mbits = 1
          port "image_classification" {}
        }
      }

      env {
        OBJECT_DETECTION_ENABLED = "${config.snoop_image_classification_object_detection_enabled}"
        OBJECT_DETECTION_MODEL = "${config.snoop_image_classification_object_detection_model}"
        IMAGE_CLASSIFICATION_ENABLED = "${config.snoop_image_classification_classify_images_enabled}"
        IMAGE_CLASSIFICATION_MODEL = "${config.snoop_image_classification_classify_images_model}"
        WAITRESS_THREADS = ${config.snoop_image_classification_waitress_threads}
      }

      service {
        name = "hoover-image-classification"
        port = "image_classification"
        tags = ["fabio-/_image-classification strip=/_image-classification"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/health"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
  {% endif %}

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
          collect_statistics_interval = 60000
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
          [rabbitmq_management].
          EOF
        #[rabbitmq_prometheus,rabbitmq_management].
      }

      service {
        name = "hoover-rabbitmq"
        port = "amqp"
      }

      service {
        name = "hoover-rabbitmq-http"
        port = "http"
        tags = ["fabio-/_rabbit"]
        check {
          name = "check-script"
          type = "script"
          command = "/bin/sh"
          args = ["-c", "time rabbitmq-diagnostics check_running"]
          interval = "${check_interval}"
          timeout = "${check_timeout}"
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
        cpu = 400
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
          name = "pg_isready"
          type = "script"
          command = "/bin/sh"
          args = ["-c", "pg_isready"]
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  {% if config.hoover_maps_enabled %}
  group "maps-tileserver" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "maps-tileserver" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "maptiler/tileserver-gl:v3.1.1"
        args = [
          "--mbtiles",
          "2020-10-planet-14.mbtiles",
        ]
        port_map {
          http = 8080
        }
        labels {
          liquid_task = "hoover-maps-tileserver"
        }
        memory_hard_limit = 900

        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover/osmdata:/data",
        ]
      }

      resources {
        memory = 200
        cpu = 100
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "hoover-maps-tileserver"
        port = "http"
        tags = ["fabio-/_maps_tileserver strip=/_maps_tileserver"]

        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "maps-osmnames-sphinxsearch" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "maps-tileserver" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "klokantech/osmnames-sphinxsearch:2.0.6"
        port_map {
          http = 80
        }
        labels {
          liquid_task = "maps-osmnames-sphinxsearch"
        }
        memory_hard_limit = 900

        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover/osmdata:/data",
        ]
      }

      resources {
        memory = 200
        cpu = 100
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "hoover-maps-tileserver"
        port = "http"
        tags = ["fabio-/_maps_osmnames_sphinxsearch strip=/_maps_osmnames_sphinxsearch"]

        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  {% endif %}

}
