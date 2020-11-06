{% from '_lib.hcl' import continuous_reschedule, set_pg_password_template, task_logs, group_disk with context -%}

job "drone-workers" {
  datacenters = ["dc1"]
  type = "system"
  priority = 98

  group "drone-workers" {
    ${ group_disk() }

    task "drone-workers" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "drone/drone-runner-docker:1"
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
        DRONE_RUNNER_ENV_FILE = "/local/drone-worker-2.env"
        DRONE_RUNNER_NAME = "{% raw %}${attr.unique.hostname}{% endraw %}"
        DRONE_RPC_PROTO = "http"
        DRONE_RUNNER_CAPACITY = 4
        DRONE_RUNNER_MAX_PROCS = 6
        DRONE_MEMORY_LIMIT = 4294967296
        DRONE_DEBUG=true
      }

      template {
        data = <<-EOF
VMCK_IP={{ env "attr.unique.network.ip-address" }}
VMCK_PORT=9990
VMCK_URL=http://{{ env "attr.unique.network.ip-address" }}:9990
${config.ci_docker_registry_env}
        EOF
        destination = "local/drone-worker-2.env"
      }

      template {
        data = <<-EOF

        DRONE_RPC_HOST = "{{ env "attr.unique.network.ip-address" }}:9990/drone-server"
        {{- with secret "liquid/ci/drone.rpc.secret" }}
          DRONE_RPC_SECRET = "{{.Data.secret_key }}"
        {{- end }}

        #DRONE_SECRET_PLUGIN_ENDPOINT = "http://{{ env "attr.unique.network.ip-address" }}:9997"
        #DRONE_SECRET_ENDPOINT = "http://{{ env "attr.unique.network.ip-address" }}:9997"
        {{- range service "drone-secret" }}
          DRONE_SECRET_PLUGIN_ENDPOINT = "http://{{.Address}}:{{.Port}}"
          DRONE_SECRET_ENDPOINT = "http://{{.Address}}:{{.Port}}"
        {{- end }}
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
      }
    }
  }
}

