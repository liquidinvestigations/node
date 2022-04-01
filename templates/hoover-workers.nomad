{% from '_lib.hcl' import set_pg_password_template, task_logs, group_disk with context -%}
{% from 'hoover.nomad' import snoop_dependency_envs with context -%}

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
        cap_add = ["mknod", "sys_admin"]
        devices = [{host_path = "/dev/fuse", container_path = "/dev/fuse"}]
        security_opt = ["apparmor=unconfined"]

        args = ["/local/startup.sh"]
        entrypoint = ["/bin/bash", "-ex"]
        volumes = [
          ${hoover_snoop2_repo}
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

      ${ snoop_dependency_envs() }

      env {
        SNOOP_MIN_WORKERS = "${config.snoop_min_workers_per_node}"
        SNOOP_MAX_WORKERS = "${config.snoop_max_workers_per_node}"
        SNOOP_CPU_MULTIPLIER = "${config.snoop_cpu_count_multiplier}"
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
