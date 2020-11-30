{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule, shutdown_delay -%}

job "drone-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  group "drone-secret" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "drone-secret" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "drone/vault:1.2"
        port_map {
          http = 3000
        }
        labels {
          liquid_task = "drone-secret"
        }
        memory_hard_limit = 1024
      }

      env {
        DRONE_DEBUG = "true"
        VAULT_ADDR = "${config.vault_url}"
        VAULT_TOKEN = "${config.vault_token}"
        VAULT_SKIP_VERIFY = "true"
        VAULT_MAX_RETRIES = "15"
      }

      template {
        data = <<-EOF
          {{- with secret "liquid/ci/drone.secret.2" }}
            DRONE_SECRET = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/drone.env"
        env = true
      }

      resources {
        memory = 150
        cpu = 150
        network {
          mbits = 1
          port "http" { }
        }
      }

      service {
        name = "drone-secret"
        port = "http"
        tags = ["fabio-:9997 proto=tcp"]
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "imghost" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "nginx" {
      ${ task_logs() }
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "nginx:1.19"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/vmck-images:/usr/share/nginx/html",
          "local/nginx.conf:/etc/nginx/nginx.conf",
        ]
        port_map {
          http = 80
        }
        memory_hard_limit = 512
      }

      resources {
        memory = 80
        cpu = 200
        network {
          port "http" {
            static = 10001
          }
        }
      }

      template {
        data = <<-EOF
          user  nginx;
          worker_processes auto;

          error_log  /var/log/nginx/error.log warn;
          pid        /var/run/nginx.pid;

          events {
            worker_connections 1024;
          }

          http {
            include       /etc/nginx/mime.types;
            default_type  application/octet-stream;

            sendfile on;
            sendfile_max_chunk 4m;
            aio threads;
            keepalive_timeout 65;
            server {
              listen 80;
              server_name  _;
              error_log /dev/stderr info;
              location / {
                root   /usr/share/nginx/html;
                autoindex on;
                proxy_max_temp_file_size 0;
                proxy_buffering off;
              }
              location = /healthcheck {
                stub_status;
              }
            }
          }
        EOF
        destination = "local/nginx.conf"
      }

      service {
        name = "vmck-imghost"
        port = "http"
        tags = ["fabio-/vmck-imghost strip=/vmck-imghost"]
        check {
          name = "vmck-imghost nginx alive on http"
          initial_status = "critical"
          type = "http"
          path = "/healthcheck"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "vmck-pg" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "vmck-pg" {
      ${ task_logs() }
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = 100
      }

      driver = "docker"

      ${ shutdown_delay() }

      config {
        image = "postgres:12"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/vmck/pg/data:/var/lib/vmck/data",
        ]
        labels {
          liquid_task = "vmck-pg"
        }
        port_map {
          pg = 5432
        }
        shm_size = 128
        memory_hard_limit = 512
      }

      template {
        data = <<EOF
          POSTGRES_USER = "vmck"
          POSTGRES_DATABASE = "vmck"
          {{- with secret "liquid/ci/vmck.postgres" }}
            POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/postgres.env"
        env = true
      }

      resources {
        cpu = 100
        memory = 256
        network {
          mbits = 1
          port "pg" {}
        }
      }

      service {
        name = "vmck-pg"
        port = "pg"
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
