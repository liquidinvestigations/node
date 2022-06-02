{% from '_lib.hcl' import authproxy_group, continuous_reschedule, set_pg_password_template, task_logs, group_disk with context -%}

{%- macro snoop_dependency_envs() %}
      env {
        SNOOP_URL_PREFIX = "snoop/"
        SNOOP_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_es"
        SNOOP_TIKA_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_tika/"
        SNOOP_BLOBS_MINIO_ADDRESS = "{% raw %}${attr.unique.network.ip-address}{% endraw %}:9991"
        SNOOP_COLLECTIONS_MINIO_ADDRESS = "{% raw %}${attr.unique.network.ip-address}{% endraw %}:9992"
        SNOOP_BROKEN_FILENAME_SERVICE = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_snoop_broken_filename_service"

        S3FS_LOGGING_LEVEL="DEBUG"

        {% if config.snoop_nlp_entity_extraction_enabled or config.snoop_nlp_language_detection_enabled %}
          SNOOP_NLP_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_nlp"
          SNOOP_EXTRACT_ENTITIES = "${config.snoop_nlp_entity_extraction_enabled}"
          SNOOP_DETECT_LANGUAGES = "${config.snoop_nlp_language_detection_enabled}"
        {% endif %}

        {% if config.snoop_translation_enabled %}
          SNOOP_TRANSLATION_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/libre_translate_batch"
          SNOOP_TRANSLATION_TARGET_LANGUAGES = "${config.snoop_translation_target_languages}"
          SNOOP_TRANSLATION_TEXT_LENGTH_LIMIT = "${config.snoop_translation_text_length_limit}"
        {% endif %}

        SNOOP_RABBITMQ_HTTP_URL = "{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_snoop_rabbit/"

        {% if config.snoop_thumbnail_generator_enabled %}
          SNOOP_THUMBNAIL_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_thumbnail-generator/"
        {% endif %}

        {% if config.snoop_pdf_preview_enabled %}
          SNOOP_PDF_PREVIEW_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_pdf-preview/"
        {% endif %}

        {% if config.snoop_image_classification_object_detection_enabled %}
          SNOOP_OBJECT_DETECTION_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_image-classification/detect-objects"
        {% endif %}

        {% if config.snoop_image_classification_classify_images_enabled %}
          SNOOP_IMAGE_CLASSIFICATION_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_image-classification/classify-image"
        {% endif %}

        SNOOP_COLLECTIONS = ${ config.snoop_collections | tojson | tojson }

        SNOOP_SKIP_PROCESSING_MIME_TYPES = "${ config.snoop_skip_mime_types }"
        SNOOP_SKIP_PROCESSING_EXTENSIONS = "${ config.snoop_skip_extensions }"

        OMP_THREAD_LIMIT = "${ config.snoop_worker_omp_thread_limit }"
        OMP_NUM_THREADS = "${ config.snoop_worker_omp_thread_limit }"

    }

      template {
        data = <<-EOF
        {{- if keyExists "liquid_debug" }}
          DEBUG = {{key "liquid_debug" | toJSON }}
        {{- end }}
        {{- range service "snoop-pg-pool" }}
          SNOOP_DB = "postgresql://snoop:
          {{- with secret "liquid/hoover/snoop.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{.Address}}:{{.Port}}/snoop"
        {{- end }}
        {{- range service "hoover-snoop-rabbitmq" }}
          SNOOP_AMQP_URL = "amqp://{{.Address}}:{{.Port}}"
        {{- end }}
        {{ range service "zipkin" }}
          TRACING_URL = "http://{{.Address}}:{{.Port}}"
        {{- end }}


          {{- with secret "liquid/hoover/snoop.minio.blobs.user" }}
              SNOOP_BLOBS_MINIO_ACCESS_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          {{- with secret "liquid/hoover/snoop.minio.blobs.password" }}
              SNOOP_BLOBS_MINIO_SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}


          {{- with secret "liquid/hoover/snoop.minio.collections.user" }}
              SNOOP_COLLECTIONS_MINIO_ACCESS_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          {{- with secret "liquid/hoover/snoop.minio.collections.password" }}
              SNOOP_COLLECTIONS_MINIO_SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}

        EOF
        destination = "local/snoop.env"
        env = true
      }

      env {
        TMP = "/alloc/data"
        TEMP = "/alloc/data"
        TMPDIR = "/alloc/data"
      }

{%- endmacro %}


{%- macro snoop_worker_group(queue, container_count=1, proc_count=1, mem_per_proc=200, cpu_per_proc=500) %}
  group "snoop-workers-${queue}" {
    ${ group_disk() }
    count = ${container_count}
    spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

    task "snoop-workers-${queue}" {
      user = "root:root"
      ${ task_logs() }

      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = -99
      }

      driver = "docker"
      config {
        ulimit { core = "0" }
        image = "${config.image('hoover-snoop2')}"
        cap_add = ["mknod", "sys_admin"]
        devices = [{host_path = "/dev/fuse", container_path = "/dev/fuse"}]
        security_opt = ["apparmor=unconfined"]

        args = ["/local/startup.sh"]
        entrypoint = ["/bin/bash", "-ex"]
        volumes = [
          ${hoover_snoop2_repo}
        ]
        labels {
          liquid_task = "snoop-workers-${queue}"
        }
        memory_hard_limit = ${3 * mem_per_proc * (proc_count)}
      }
      # used to auto-restart containers when running deploy, after you make a new commit
      env { __GIT_TAGS = "${hoover_snoop2_git}" }

      resources {
        memory = ${mem_per_proc * (proc_count)}
        cpu = ${cpu_per_proc * proc_count}
      }

      template {
        data = <<-EOF
          #!/bin/bash
          set -ex
          # exec tail -f /dev/null
          if  [ -z "$SNOOP_TIKA_URL" ] \
                  || [ -z "$SNOOP_DB" ] \
                  || [ -z "$SNOOP_ES_URL" ] \
                  || [ -z "$SNOOP_AMQP_URL" ]; then
            echo "incomplete configuration!"
            sleep 5
            exit 1
          fi
          exec ./manage.py runworkers --queue ${queue} --mem ${mem_per_proc} --count ${proc_count}
          EOF
        env = false
        destination = "local/startup.sh"
      }

      ${ snoop_dependency_envs() }

      # these have very high load!
      # service {
      #   check {
      #     name = "check-workers-script-${queue}"
      #     type = "script"
      #     command = "/bin/bash"
      #     args = ["-exc", "cd /opt/hoover/snoop; ./manage.py checkworkers"]
      #     interval = "${check_interval}"
      #     timeout = "${check_timeout}"
      #   }
      # }
    }
  }
{%- endmacro %}

job "hoover" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }


  group "search" {
    count = ${config.hoover_web_count}
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "search" {
      ${ task_logs() }

      driver = "docker"

      config {
        image = "${config.image('hoover-search')}"
        args = ["bash", "/local/startup.sh"]
        volumes = [
          ${hoover_search_repo}
        ]
        port_map {
          http = 8080
        }
        labels {
          liquid_task = "hoover-search"
        }
        memory_hard_limit = ${3 * config.hoover_web_memory_limit}
      }
      # This container uses "runserver" so we don't need to auto-reload
      # env { __GIT_TAGS = "${hoover_search_git}" }

      resources {
        memory = ${config.hoover_web_memory_limit}
        network {
          mbits = 1
          port "http" {}
        }
      }

      template {
        data = <<-EOF
        #!/bin/bash
        set -ex
        (
        set +x
        if [ -z "$HOOVER_DB" ]; then
          echo "database not ready"
          sleep 5
          exit 1
        fi
        )
        /wait
        ./manage.py migrate
        ./manage.py healthcheck
        ./manage.py synccollections "$SNOOP_COLLECTIONS"

        if [[ "$DEBUG" == "true" ]]; then
          exec ./manage.py runserver 0.0.0.0:8080
        else
          exec waitress-serve --port 8080 --threads=20 hoover.site.wsgi:application
        fi
        EOF
        env = false
        destination = "local/startup.sh"
      }

      env {
        HOOVER_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_es"
        SNOOP_COLLECTIONS = ${ config.snoop_collections | tojson | tojson }
        SNOOP_BASE_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/snoop"
      }

      template {
        data = <<-EOF
          {{- if keyExists "liquid_debug" }}
            DEBUG = {{key "liquid_debug" | toJSON }}
          {{- end }}
          {{- with secret "liquid/hoover/search.django" }}
            SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          {{- range service "search-pg" }}
            HOOVER_DB = "postgresql://search:
            {{- with secret "liquid/hoover/search.postgres" -}}
              {{.Data.secret_key }}
            {{- end -}}
            @{{.Address}}:{{.Port}}/search"
          {{- end }}

          #HOOVER_HOSTNAME = "hoover.{{key "liquid_domain"}}"
          HOOVER_HOSTNAME = "*"
          HOOVER_TITLE = "Hoover"
          HOOVER_LIQUID_TITLE = "${config.liquid_title}"
          HOOVER_LIQUID_URL = "${config.liquid_core_url}"
          HOOVER_AUTHPROXY = "true"
          USE_X_FORWARDED_HOST = "true"
          LIQUID_CORE_LOGOUT_URL = "${config.liquid_core_url}/accounts/logout/?next=/"
          {%- if config.liquid_http_protocol == 'https' %}
            SECURE_PROXY_SSL_HEADER = "HTTP_X_FORWARDED_PROTO"
          {%- endif %}
          HOOVER_RATELIMIT_USER = ${config.hoover_ratelimit_user|tojson}
          HOOVER_ES_MAX_CONCURRENT_SHARD_REQUESTS = "${config.hoover_es_max_concurrent_shard_requests}"
          {{- range service "hoover-search-rabbitmq" }}
            SEARCH_AMQP_URL = "amqp://{{.Address}}:{{.Port}}"
          {{- end }}
        EOF
        destination = "local/hoover.env"
        env = true
      }

      service {
        name = "hoover-search"
        port = "http"
        tags = ["fabio-/hoover-search strip=/hoover-search"]

        check {
          name = "http_ping"
          initial_status = "critical"
          type = "http"
          path = "/api/v1/_ping"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["hoover.${liquid_domain}"]
          }
        }

        check_restart {
          limit = 7
          grace = "495s"
        }
      }
    }
  }


  group "snoop-web" {
    count = ${config.hoover_web_count}
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "snoop" {
      user = "root:root"
      ${ task_logs() }

      driver = "docker"

      config {
        image = "${config.image('hoover-snoop2')}"
        cap_add = ["mknod", "sys_admin"]
        devices = [{host_path = "/dev/fuse", container_path = "/dev/fuse"}]
        security_opt = ["apparmor=unconfined"]

        args = ["/local/startup.sh"]
        entrypoint = ["/bin/bash", "-ex"]
        volumes = [
          ${hoover_snoop2_repo}
        ]
        port_map {
          http = 8080
        }
        labels {
          liquid_task = "snoop-api"
        }
        memory_hard_limit = ${3 * config.hoover_web_memory_limit}
      }
      # This container uses "runserver" so we don't need to auto-reload
      # env { __GIT_TAGS = "${hoover_snoop2_git}" }

      template {
        data = <<-EOF
          #!/bin/bash
          set -ex
          if [ -z "$SNOOP_ES_URL" ] || [ -z "$SNOOP_DB" ]; then
            echo "incomplete configuration!"
            sleep 5
            exit 1
          fi
          date
          ./manage.py migrate --noinput
          ./manage.py migratecollections
          ./manage.py healthcheck
          date
          if [[ "$DEBUG" == "true" ]]; then
            exec ./manage.py runserver 0.0.0.0:8080
          else
            exec /runserver
          fi
          EOF
        env = false
        destination = "local/startup.sh"
      }

      ${ snoop_dependency_envs() }

      resources {
        memory = ${config.hoover_web_memory_limit}
        cpu = 200
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "hoover-snoop"
        port = "http"
        tags = ["fabio-/snoop"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/snoop/_health"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["snoop.${liquid_domain}"]
          }
        }
      }
    }
  }

  # SNOOP WORKERS
  # =============

  {% if config.snoop_workers_enabled %}

  group "snoop-celery-beat" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "snoop-celery-beat" {
      user = "root:root"
      ${ task_logs() }

      driver = "docker"
      config {
        entrypoint = ["/bin/bash", "-ex"]
        image = "${config.image('hoover-snoop2')}"
        args = ["/local/startup.sh"]
        volumes = [
          ${hoover_snoop2_repo}
        ]
        memory_hard_limit = 400
      }
      # used to auto-restart containers when running deploy, after you make a new commit
      env { __GIT_TAGS = "${hoover_snoop2_git}" }

      template {
        data = <<-EOF
          #!/bin/bash
          set -ex
          if  [ -z "$SNOOP_DB" ] \
                  || [ -z "$SNOOP_ES_URL" ] \
                  || [ -z "$SNOOP_AMQP_URL" ]; then
            echo "incomplete configuration!"
            sleep 5
            exit 1
          fi
          exec celery -A snoop.data beat -l INFO --pidfile= -s /tmp/celery-beat-db
          EOF
        env = false
        destination = "local/startup.sh"
      }

      ${ snoop_dependency_envs() }

      resources {
        memory = 100
      }
    }
  } // snoop-celery-beat

    # SYSTEM GROUP
    # ============
    ${ snoop_worker_group(
        queue="system",
        container_count=1,
        proc_count=3,
      ) }

    # CPU WORKER GROUPS
    # =================
    ${ snoop_worker_group(
        queue="default",
        container_count=config.snoop_default_queue_worker_count,
        proc_count=config.snoop_container_process_count,
        mem_per_proc=500,
        cpu_per_proc=1000,
      ) }

    ${ snoop_worker_group(
        queue="filesystem",
        container_count=config.snoop_filesystem_queue_worker_count,
        proc_count=config.snoop_container_process_count,
        mem_per_proc=500,
        cpu_per_proc=1000,
      ) }

    ${ snoop_worker_group(
        queue="ocr",
        container_count=config.snoop_ocr_queue_worker_count,
        proc_count=config.snoop_container_process_count,
        mem_per_proc=500,
        cpu_per_proc=1000,
      ) }

    ${ snoop_worker_group(
        queue="digests",
        container_count=config.snoop_digests_queue_worker_count,
        proc_count=config.snoop_container_process_count,
        mem_per_proc=500,
        cpu_per_proc=1000,
      ) }

    # HTTP CLIENT WORKER GROUPS
    # =========================

    ${ snoop_worker_group(
        queue="tika",
        container_count=config.tika_count,
        proc_count=config.snoop_container_process_count,
      ) }

    {% if config.snoop_nlp_entity_extraction_enabled or config.snoop_nlp_language_detection_enabled %}
    ${ snoop_worker_group(
        queue="entities",
        container_count=config.snoop_nlp_count,
        proc_count=config.snoop_container_process_count,
      ) }
    {% endif %}

    {% if config.snoop_translation_enabled %}
    ${ snoop_worker_group(
        queue="translate",
        container_count=config.snoop_translation_count,
        proc_count=config.snoop_container_process_count,
      ) }
    {% endif %}

    {% if config.snoop_image_classification_classify_images_enabled or config.snoop_image_classification_object_detection_enabled %}
    ${ snoop_worker_group(
        queue="img-cls",
        container_count=config.snoop_image_classification_count,
        proc_count=config.snoop_container_process_count,
      ) }
    {% endif %}

    {% if config.snoop_pdf_preview_enabled %}
    ${ snoop_worker_group(
        queue="pdf-preview",
        container_count=config.snoop_pdf_preview_count,
        proc_count=config.snoop_container_process_count,
      ) }
    {% endif %}

    {% if config.snoop_thumbnail_generator_enabled %}
    ${ snoop_worker_group(
        queue="thumbnails",
        container_count=config.snoop_thumbnail_generator_count,
        proc_count=config.snoop_container_process_count,
      ) }
    {% endif %}

  {% endif %}
}
