{% from '_lib.hcl' import authproxy_group, continuous_reschedule, set_pg_password_template, task_logs, group_disk with context -%}

{%- macro snoop_dependency_envs() %}
      env {
        SNOOP_URL_PREFIX = "snoop/"
        SNOOP_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/_es"
        SNOOP_TIKA_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/_tika/"
        SNOOP_BLOBS_MINIO_ADDRESS = "{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_blobs_minio}"
        SNOOP_COLLECTIONS_MINIO_ADDRESS = "{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_collections_minio}"
        SNOOP_BROKEN_FILENAME_SERVICE = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/_snoop_broken_filename_service"

        S3FS_LOGGING_LEVEL="INFO"

        {% if config.snoop_nlp_entity_extraction_enabled or config.snoop_nlp_language_detection_enabled %}
          SNOOP_NLP_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/_nlp"
          SNOOP_EXTRACT_ENTITIES = "${config.snoop_nlp_entity_extraction_enabled}"
          SNOOP_DETECT_LANGUAGES = "${config.snoop_nlp_language_detection_enabled}"
        {% endif %}

        {% if config.snoop_translation_enabled %}
          SNOOP_TRANSLATION_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/libre_translate_batch"
          SNOOP_TRANSLATION_TARGET_LANGUAGES = "${config.snoop_translation_target_languages}"
          SNOOP_TRANSLATION_TEXT_LENGTH_LIMIT = "${config.snoop_translation_text_length_limit}"
        {% endif %}

        SNOOP_RABBITMQ_HTTP_URL = "{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/_snoop_rabbit/"

        {% if config.snoop_thumbnail_generator_enabled %}
          SNOOP_THUMBNAIL_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/_thumbnail-generator/"
        {% endif %}

        {% if config.snoop_pdf_preview_enabled %}
          SNOOP_PDF_PREVIEW_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/_pdf-preview/"
        {% endif %}

        {% if config.snoop_image_classification_object_detection_enabled %}
          SNOOP_OBJECT_DETECTION_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/_image-classification/detect-objects"
        {% endif %}

        {% if config.snoop_image_classification_classify_images_enabled %}
          SNOOP_IMAGE_CLASSIFICATION_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/_image-classification/classify-image"
        {% endif %}

        SNOOP_COLLECTIONS = ${ config.snoop_collections | tojson | tojson }

        SNOOP_SKIP_PROCESSING_MIME_TYPES = "${ config.snoop_skip_mime_types }"
        SNOOP_SKIP_PROCESSING_EXTENSIONS = "${ config.snoop_skip_extensions }"

        OMP_THREAD_LIMIT = "${ config.snoop_worker_omp_thread_limit }"
        OMP_NUM_THREADS = "${ config.snoop_worker_omp_thread_limit }"
        SNOOP_OCR_PROCESSES_PER_DOC = "${ config.snoop_ocr_parallel_pages }"
        SNOOP_UNARCHIVE_THREADS = "${ config.snoop_unarchive_threads }"

        SNOOP_TOTAL_WORKER_COUNT = "${config.total_snoop_worker_count}"

        GUNICORN_WORKER_CLASS = "gthread"
        GUNICORN_WORKERS = "3"
        GUNICORN_THREADS = "8"
        GUNICORN_MAX_REQUESTS = "1000"
    }

      template {
        data = <<-EOF
        {{- if keyExists "liquid_debug" }}
          DEBUG = {{key "liquid_debug" | toJSON }}
        {{- end }}
        SNOOP_DB = "postgresql://snoop:
        {{- with secret "liquid/hoover/snoop.postgres" -}}
          {{.Data.secret_key }}
        {{- end -}}
        @{{env "attr.unique.network.ip-address" }}:${config.port_snoop_pg_pool}/snoop"
        SNOOP_AMQP_URL = "amqp://{{env "attr.unique.network.ip-address" }}:${config.port_snoop_rabbitmq}"

        TRACING_URL = "http://{{ env "attr.unique.network.ip-address" }}:${config.port_zipkin}"

        UPTRACE_DSN = "http://hoover@{{ env "attr.unique.network.ip-address" }}:${config.port_uptrace_native}/4"


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


job "hoover" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }


  group "search" {
    count = ${config.hoover_web_count}
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "search" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"

      config {
        image = "${config.image('hoover-search')}"
        volumes = [
          ${hoover_search_repo}
          "{% raw %}${meta.liquid_collections}{% endraw %}:/opt/hoover/collections",
        ]
        port_map {
          http = 8000
        }
        labels {
          liquid_task = "hoover-search"
        }
        memory_hard_limit = ${4 * config.hoover_web_memory_limit}
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

      env {
        HOOVER_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/_es"
        SNOOP_COLLECTIONS = ${ config.snoop_collections | tojson | tojson }
        SNOOP_BASE_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/snoop"
        DEBUG_WAIT_PER_COLLECTION = ${config.hoover_search_debug_delay}

        GUNICORN_WORKER_CLASS = "gthread"
        GUNICORN_WORKERS = "3"
        GUNICORN_THREADS = "8"
        GUNICORN_MAX_REQUESTS = "1000"
      }

      template {
        data = <<-EOF
          {{- if keyExists "liquid_debug" }}
            DEBUG = {{key "liquid_debug" | toJSON }}
          {{- end }}
          {{- with secret "liquid/hoover/search.django" }}
            SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          HOOVER_DB = "postgresql://search:
          {{- with secret "liquid/hoover/search.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{env "attr.unique.network.ip-address" }}:${config.port_search_pg}/search"

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
          SEARCH_AMQP_URL = "amqp://{{env "attr.unique.network.ip-address" }}:${config.port_search_rabbitmq}"

          UPTRACE_DSN = "http://hoover@{{ env "attr.unique.network.ip-address" }}:${config.port_uptrace_native}/4"
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
          grace = "995s"
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

        entrypoint = ["/tini", "--", "/bin/bash", "-ex"]
        args = ["/local/startup.sh"]
        volumes = [
          ${hoover_snoop2_repo}
        ]
        port_map {
          http = 8080
        }
        labels {
          liquid_task = "snoop-api"
        }
        memory_hard_limit = ${4 * config.hoover_web_memory_limit}
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

          exec /runserver

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
}
