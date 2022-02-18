{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "hoover-deps-downloads" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 99

  group "dummy-task" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "dummy-task" {
      leader = true

      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      constraint {
        attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
        operator = "is_set"
      }

      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["-c", "echo OK"]
      }
    }
  }

  {% if config.snoop_nlp_entity_extraction_enabled or config.snoop_nlp_language_detection_enabled %}
  group "download-nlp-service-data" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "download-nlp-service-data" {
      leader = true

      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "${config.image('nlp-service')}"
        command = "/opt/app/download"
        labels {
          liquid_task = "download-nlp-service-data"
        }
        memory_hard_limit = 1000
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nlp-service/data:/data",
        ]
      }

      env {
        NLP_SERVICE_PRESET = "${config.snoop_nlp_preset}"
        NLP_SERVICE_FALLBACK_LANGUAGE = "${config.snoop_nlp_fallback_language}"
        NLP_SPACY_TEXT_LIMIT = "${config.snoop_nlp_spacy_text_limit}"
        GUNICORN_WORKERS = ${config.snoop_nlp_gunicorn_workers}
        GUNICORN_THREADS = ${config.snoop_nlp_gunicorn_threads}
      }

      resources {
        memory = 200
        cpu = 200
        network {
          mbits = 1
        }
      }
    }
  }
  {% endif %}
}
