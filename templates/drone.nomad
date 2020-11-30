{% from '_lib.hcl' import group_disk, task_logs -%}

job "drone" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  group "drone" {
    ${ group_disk() }
    task "drone" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }
      driver = "docker"
      config {
        image = "liquidinvestigations/drone:master"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/drone:/data",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "drone"
        }
        memory_hard_limit = 2048
      }

      env {
        DRONE_GITHUB_SERVER = "https://github.com"
        DRONE_SERVER_HOST = "jenkins.${liquid_domain}"
        DRONE_SERVER_PROTO = "${config.liquid_http_protocol}"
        DRONE_DATADOG_ENABLED = "false"
        DRONE_CLEANUP_DEADLINE_PENDING = "12h"
        DRONE_CLEANUP_DEADLINE_RUNNING = "2h"
        DRONE_CLEANUP_INTERVAL = "60m"
        DRONE_CLEANUP_DISABLED = "false"
      }

      template {
        data = <<-EOF

        {{- with secret "liquid/ci/drone.rpc.secret" }}
          DRONE_RPC_SECRET = "{{.Data.secret_key }}"
        {{- end }}

        {{- with secret "liquid/ci/drone.github" }}
          DRONE_GITHUB_CLIENT_ID = {{.Data.client_id | toJSON }}
          DRONE_GITHUB_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
          DRONE_USER_FILTER = {{.Data.user_filter | toJSON }}
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
        destination = "local/drone.env"
        env = true
      }

      resources {
        memory = 350
        cpu = 150
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "drone"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:jenkins.${liquid_domain}",
          "fabio-/drone-server strip=/drone-server",
        ]
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


  group "vmck" {
    task "vmck" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator  = "is_set"
      }

      driver = "docker"
      config {
        image = "vmck/vmck:0.5.1"
        hostname = "{% raw %}${attr.unique.hostname}{% endraw %}"
        dns_servers = ["{% raw %}${attr.unique.network.ip-address}{% endraw %}"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/vmck:/opt/vmck/data",
        ]
        port_map {
          http = 8000
        }
        memory_hard_limit = 1024
      }

      env {
          CONSUL_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8500"
          NOMAD_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:4646"
          QEMU_IMAGE_PATH_PREFIX = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/vmck-imghost"
      }

      template {
        data = <<-EOF
          {{- with secret "liquid/ci/vmck.django" }}
            SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          HOSTNAME = "*"
          SSH_USERNAME = "vagrant"
          VMCK_URL = 'http://{{ env "NOMAD_ADDR_http" }}'
          BACKEND = "qemu"
          QEMU_CPU_MHZ = "{{ env "attr.cpu.frequency" }}"
          # nomad reserves 20000-32000
          VM_PORT_RANGE_START = 32010
          VM_PORT_RANGE_STOP = 40000
          EOF
          destination = "local/vmck.env"
          env = true
      }

      resources {
        memory = 450
        cpu = 350
        network {
          port "http" { }
        }
      }

      service {
        name = "vmck"
        port = "http"
        tags = ["fabio-/v0"]
        check {
          name = "vmck alive on http"
          initial_status = "critical"
          type = "http"
          path = "/v0/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
