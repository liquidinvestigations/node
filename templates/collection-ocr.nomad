{% from '_lib.hcl' import group_disk, task_logs, promtail_task -%}

job "collection-${name}-ocr{% if periodic %}-${periodic}{% endif %}" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 25

  {% if periodic %}
  periodic {
    cron  = "${periodic}"
    prohibit_overlap = true
  }
  {% endif %}

  group "tesseract" {
    ${ group_disk() }

    task "tesseract" {
      leader = true

      constraint {
        attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "liquidinvestigations/tesseract-batch:latest"
        volumes = [
          "{% raw %}${meta.liquid_collections}{% endraw %}/${name}/data/ocr:/data",
          "{% raw %}${meta.liquid_collections}{% endraw %}/${name}/ocr/tesseract-batch:/ocr",
        ]
        labels {
          liquid_task = "collection-${name}-ocr"
        }
      }
      resources {
        memory = 2048
        cpu = 3000
      }

      env {
        {% if threads_per_worker %}
        OMP_NUM_THREADS = "${threads_per_worker}"
        {% endif %}

        {% if workers %}
        WORKER_COUNT = "${workers}"
        {% endif %}

        {% if nice %}
        WORKER_NICE = "${nice}"
        {% endif %}
      }
    }
    ${ promtail_task() }
  }
}
