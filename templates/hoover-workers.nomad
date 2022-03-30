{% from '_lib.hcl' import set_pg_password_template, task_logs, group_disk with context -%}

job "hoover-workers" {
  datacenters = ["dc1"]
  type = "system"
  priority = 90

  group "snoop-workers" {
    ${ group_disk() }

    task "snoop-workers" {
      user = "root:root"
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      constraint {
        attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "${config.image('hoover-snoop2')}"
        args = ["/local/startup.sh"]
        entrypoint = ["/bin/bash", "-ex"]
        volumes = [
          ${hoover_snoop2_repo}
          "{% raw %}${meta.liquid_collections}{% endraw %}:/opt/hoover/collections",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/snoop/tmp:/opt/hoover/snoop/tmp",
        ]
        mounts = [
          {
            type = "tmpfs"
            target = "/tmp"
            readonly = false
            tmpfs_options {
              #size = 3221225472  # 3G
            }
          }
        ]
        labels {
          liquid_task = "snoop-workers"
        }
        memory_hard_limit = ${config.snoop_worker_hard_memory_limit}
      }
      # used to auto-restart containers when running deploy, after you make a new commit
      env { __GIT_TAGS = "${hoover_snoop2_git}" }

      resources {
        memory = ${config.snoop_worker_memory_limit}
        cpu = ${config.snoop_worker_cpu_limit}
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
          exec ./manage.py runworkers
          EOF
        env = false
        destination = "local/startup.sh"
      }

      env {
        SNOOP_ES_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_es"
        SNOOP_TIKA_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_tika/"
        SNOOP_BLOBS_MINIO_ADDRESS = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9991"
        {% if config.snoop_thumbnail_generator_enabled %}
          SNOOP_THUMBNAIL_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_thumbnail-generator/"
        {% endif %}
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
        SNOOP_COLLECTIONS = ${ config.snoop_collections | tojson | tojson }
        {% if config.snoop_pdf_preview_enabled %}
          SNOOP_PDF_PREVIEW_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_pdf-preview/"
        {% endif %}
        {% if config.snoop_image_classification_classify_images_enabled %}
          SNOOP_IMAGE_CLASSIFICATION_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_image-classification/classify-image"
        {% endif %}
        {% if config.snoop_image_classification_object_detection_enabled %}
          SNOOP_OBJECT_DETECTION_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/_image-classification/detect-objects"
        {% endif %}

        SNOOP_MIN_WORKERS = "${config.snoop_min_workers_per_node}"
        SNOOP_MAX_WORKERS = "${config.snoop_max_workers_per_node}"
        SNOOP_CPU_MULTIPLIER = "${config.snoop_cpu_count_multiplier}"

        SNOOP_COLLECTION_ROOT = "/opt/hoover/collections"
        SYNC_FILES = "${sync}"
      }
      template {
        data = <<-EOF
        {{- if keyExists "liquid_debug" }}
          DEBUG = {{key "liquid_debug" | toJSON }}
        {{- end }}
        {{- range service "snoop-pg" }}
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


          {{- with secret "liquid/hoover/snoop.minio.blobs.access_key" }}
              SNOOP_BLOBS_MINIO_ACCESS_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          {{- with secret "liquid/hoover/snoop.minio.blobs.secret_key" }}
              SNOOP_BLOBS_MINIO_SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}

        EOF
        destination = "local/snoop.env"
        env = true
      }

      #service {
      #  check {
      #    name = "check-workers-script"
      #    type = "script"
      #    command = "/bin/bash"
      #    args = ["-exc", "cd /opt/hoover/snoop; ./manage.py checkworkers"]
      #    interval = "${check_interval}"
      #    timeout = "${check_timeout}"
      #  }
      #}
    }
  }
}
