{% from '_lib.hcl' import authproxy_group, continuous_reschedule, set_pg_password_template, task_logs, group_disk with context -%}

{% from 'hoover.nomad' import snoop_dependency_envs with context %}


{%- macro snoop_worker_group(queue, container_count=1, proc_count=1, mem_per_proc=450, cpu_per_proc=700) %}
  group "snoop-workers-${queue}" {
    ${ group_disk() }
    ${ continuous_reschedule() }
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
        memory_hard_limit = ${int(1.5 * mem_per_proc * proc_count)}
      }
      # used to auto-restart containers when running deploy, after you make a new commit
      env { __GIT_TAGS = "${hoover_snoop2_git}" }

      resources {
        memory = ${mem_per_proc * proc_count}
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

job "hoover-workers" {
  datacenters = ["dc1"]
  type = "service"
  priority = 10

  spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

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
        mem_per_proc=400,
        cpu_per_proc=1500,
      ) }

    ${ snoop_worker_group(
        queue="filesystem",
        container_count=config.snoop_filesystem_queue_worker_count,
        proc_count=config.snoop_container_process_count,
        mem_per_proc=800,
        cpu_per_proc=1200,
      ) }

    ${ snoop_worker_group(
        queue="ocr",
        container_count=config.snoop_ocr_queue_worker_count,
        proc_count=config.snoop_container_process_count,
        mem_per_proc=500,
        cpu_per_proc=1500,
      ) }

    ${ snoop_worker_group(
        queue="digests",
        container_count=config.snoop_digests_queue_worker_count,
        proc_count=config.snoop_container_process_count,
        mem_per_proc=800,
        cpu_per_proc=1200,
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
