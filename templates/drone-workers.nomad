{% from '_lib.hcl' import set_pg_password_template, task_logs, group_disk with context -%}

{% macro worker_task_def() %}
      ${ task_logs() }

      driver = "docker"
      config {
        image = "drone/drone-runner-docker:1.6"
        memory_hard_limit = 2000

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
        ]

        port_map {
          http = 3000
        }
      }
      resources {
        memory = 250
        cpu = 250
        network {
          mbits = 1
          port "http" {}
        }
      }

      env {
        #DRONE_RUNNER_ENV_FILE = "/local/drone-worker-2.env"
        DRONE_RPC_PROTO = "http"
        DRONE_MEMORY_LIMIT = 12624855040
        DRONE_DEBUG=true
      }

      template {
        data = <<-EOF

        DRONE_RPC_HOST = "{{ env "attr.unique.network.ip-address" }}:10002"

        {{- with secret "liquid/ci/drone.rpc.secret" }}
          DRONE_RPC_SECRET = "{{.Data.secret_key }}"
        {{- end }}

        DRONE_SECRET_PLUGIN_ENDPOINT = "http://{{ env "attr.unique.network.ip-address" }}:10003"
        DRONE_SECRET_ENDPOINT = "http://{{ env "attr.unique.network.ip-address" }}:10003"
        {{- with secret "liquid/ci/drone.secret.2" }}
          DRONE_SECRET_PLUGIN_SECRET = {{.Data.secret_key | toJSON }}
          DRONE_SECRET_SECRET = {{.Data.secret_key | toJSON }}
        {{- end }}
        DRONE_SECRET_PLUGIN_SKIP_VERIFY = "true"
        DRONE_SECRET_SKIP_VERIFY = "true"

        EOF
        destination = "local/drone-worker.env"
        env = true
      }

      service {
        name = "drone-worker"
        port = "http"

        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }

{% endmacro %}

job "drone-workers" {
  datacenters = ["dc1"]
  type = "system"
  priority = 98

  group "drone-workers" {
    ${ group_disk() }

    task "drone-workers" {

      # TODO: fix stability when drone is running on more than 1 host
      # till then: we only run workers on the machine with the volumes
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ worker_task_def() }

      env {
        DRONE_RUNNER_CAPACITY = 2
        DRONE_RUNNER_MAX_PROCS = 2
        DRONE_RUNNER_NAME = "{% raw %}${attr.unique.hostname}{% endraw %}-default"
      }
    }
  }
}

