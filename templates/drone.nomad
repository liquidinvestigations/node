{% from '_lib.hcl' import group_disk, task_logs -%}

job "drone" {
  datacenters = ["dc1"]
  type = "service"
  priority = 90

  group "imghost" {
    ${ group_disk() }

    task "nginx" {
      ${ task_logs() }
      driver = "docker"
      config {
        image = "nginx:mainline"
        volumes = [
          "${liquid_volumes}/vmck-images:/usr/share/nginx/html",
          "local/nginx.conf:/etc/nginx/nginx.conf",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "vmck-imghost-nginx"
        }
      }
      resources {
        memory = 80
        cpu = 200
        network {
          port "http" {
            static = 10000
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
            worker_connections  1024;
          }

          http {
            include       /etc/nginx/mime.types;
            default_type  application/octet-stream;

            log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                              '$status $body_bytes_sent "$http_referer" '
                              '"$http_user_agent" "$http_x_forwarded_for"';

            access_log  /var/log/nginx/access.log  main;

            sendfile        on;
            sendfile_max_chunk 4m;
            aio threads;
            keepalive_timeout  65;
            server {
              listen       80;
              server_name  _;
              access_log  /dev/stdout  main;
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

  group "vmck-smallimgs" {
    ${ group_disk() }

    task "vmck-smallimgs" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('vmck/vmck')}"
        args = ["sh", "/local/startup.sh"]
        volumes = [
          "${liquid_volumes}/vmck:/opt/vmck/data",
        ]
        port_map {
          http = 8000
        }
        labels {
          liquid_task = "vmck"
        }
      }
      template {
        data = <<-EOF
        #!/bin/sh
        set -ex
        echo
        echo
        date
        cat /local/vmck.env
        cat /local/vmck-imghost.env
        cat /local/startup.sh
        if [ -z "$QEMU_IMAGE_URL" ]; then
          echo "NO QEMU_IMAGE_URL!"
          sleep 5
          exit 1
        fi
        exec /opt/vmck/runvmck
        EOF
        env = false
        destination = "local/startup.sh"
      }
      template {
        data = <<-EOF
        {{- with secret "liquid/ci/vmck.django" -}}
          SECRET_KEY = {{.Data.secret_key}}
        {{- end }}
        HOSTNAME=*
        SSH_USERNAME=vagrant
        CONSUL_URL=${config.consul_url}
        NOMAD_URL=${config.nomad_url}
        BACKEND=qemu
        QEMU_CPU_MHZ=3000
        EOF
        destination = "local/vmck.env"
        env = true
      }
      template {
        data = <<-EOF
        {{- range service "vmck-imghost" -}}
          QEMU_IMAGE_URL=http://{{.Address}}:{{.Port}}/imgbuild-master.qcow2.tar.gz
        {{- end }}
        EOF
        destination = "local/vmck-imghost.env"
        env = true
      }
      resources {
        memory = 450
        cpu = 350
        network {
          port "http" {
            static = 11111
          }
        }
      }
      service {
        name = "vmck-smallimgs"
        port = "http"
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

  group "vmck" {
    ${ group_disk() }

    task "vmck" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('vmck/vmck')}"
        args = ["sh", "/local/startup.sh"]
        volumes = [
          "${liquid_volumes}/vmck:/opt/vmck/data",
        ]
        port_map {
          http = 8000
        }
        labels {
          liquid_task = "vmck"
        }
      }
      template {
        data = <<-EOF
        #!/bin/sh
        set -ex
        echo
        echo
        date
        cat /local/vmck.env
        cat /local/vmck-imghost.env
        cat /local/startup.sh
        if [ -z "$QEMU_IMAGE_URL" ]; then
          echo "NO QEMU_IMAGE_URL!"
          sleep 5
          exit 1
        fi
        exec /opt/vmck/runvmck
        EOF
        env = false
        destination = "local/startup.sh"
      }
      template {
        data = <<-EOF
        {{- with secret "liquid/ci/vmck.django" -}}
          SECRET_KEY = {{.Data.secret_key}}
        {{- end }}
        HOSTNAME=*
        SSH_USERNAME=vagrant
        CONSUL_URL=${config.consul_url}
        NOMAD_URL=${config.nomad_url}
        BACKEND=qemu
        QEMU_CPU_MHZ=3000
        EOF
        destination = "local/vmck.env"
        env = true
      }
      template {
        data = <<-EOF
        {{- range service "vmck-imghost" -}}
          QEMU_IMAGE_URL=http://{{.Address}}:{{.Port}}/cluster-master.qcow2.tar.gz
        {{- end }}
        EOF
        destination = "local/vmck-imghost.env"
        env = true
      }
      resources {
        memory = 450
        cpu = 350
        network {
          port "http" {
            static = 9995
          }
        }
      }
      service {
        name = "vmck"
        port = "http"
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

  group "drone-secret" {
    ${ group_disk() }
    task "drone-secret" {
      ${ task_logs() }
      driver = "docker"
      config {
        image = "drone/vault"
        port_map {
          http = 3000
        }
        labels {
          liquid_task = "drone-secret"
        }
      }
      env {
        VAULT_ADDR = "${config.vault_url}"
        VAULT_TOKEN = "${config.vault_token}"
        VAULT_SKIP_VERIFY = "true"
        VAULT_MAX_RETRIES = "5"
      }
      template {
        data = <<-EOF
          {{- with secret "liquid/ci/drone.secret" }}
            SECRET_KEY={{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/drone.env"
        env = true
      }
      resources {
        memory = 150
        cpu = 150
        network {
          port "http" {
            static = 9996
          }
        }
      }
      service {
        name = "drone-secret"
        port = "http"
        check {
          name = "drone-secret alive on tcp, because the http is authenticated"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }


  group "drone" {
    ${ group_disk() }
    task "drone" {
      ${ task_logs() }
      driver = "docker"
      config {
        image = "drone/drone:1.2.0"
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
          "${liquid_volumes}/drone:/data",
        ]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "drone"
        }
      }
      env {
        DRONE_LOGS_DEBUG = "true"
        DRONE_GITHUB_SERVER = "https://github.com"
        DRONE_SERVER_HOST = "jenkins.${liquid_domain}"
        DRONE_SERVER_PROTO = "${config.liquid_http_protocol}"
        DRONE_RUNNER_CAPACITY = "${config.ci_runner_capacity}"
      }
      template {
        data = <<-EOF
          {{- range service "vmck" }}
            DRONE_RUNNER_ENVIRON=VMCK_IP:{{.Address}},VMCK_PORT:{{.Port}}
          {{- end }}
          {{- range service "drone-secret" }}
            DRONE_SECRET_ENDPOINT=http://{{.Address}}:{{.Port}}
          {{- end }}
          {{- with secret "liquid/ci/drone.secret" }}
            DRONE_SECRET_SECRET={{.Data.secret_key | toJSON }}
          {{- end }}
          {{- with secret "liquid/ci/drone.github" }}
            DRONE_GITHUB_CLIENT_ID={{.Data.client_id | toJSON }}
            DRONE_GITHUB_CLIENT_SECRET={{.Data.client_secret | toJSON }}
            DRONE_USER_FILTER={{.Data.user_filter | toJSON }}
          {{- end }}
        EOF
        destination = "local/drone.env"
        env = true
      }
      resources {
        memory = 250
        cpu = 150
        network {
          port "http" {
            static = 9997
          }
        }
      }
      service {
        name = "drone"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:jenkins.${liquid_domain}",
        ]
        check {
          name = "drone alive on http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
