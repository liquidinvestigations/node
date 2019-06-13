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
          "custom/default.conf:/etc/nginx/conf.d/default.conf",
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
          port "http" {}
        }
      }
      template {
        data = <<EOF
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
          }
        EOF
        destination = "custom/default.conf"
      }
      service {
        name = "vmck-imghost"
        port = "http"
        check {
          name = "vmck-imghost nginx alive on http"
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
    ${ group_disk() }

    task "vmck" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "vmck/vmck:0.0.1-permit-archived-artifact"
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
        if [ -z "$QEMU_IMAGE_URL" ]; then
          echo "NO QEMU_IMAGE_URL!"
          sleep 10
          exit 1
        fi
        exec /opt/vmck/runvmck
        EOF
        env = false
        destination = "local/startup.sh"
      }
      template {
        data = <<-EOF
        {{- with secret "liquid/ci/vmck.django" }}
          SECRET_KEY = {{.Data.secret_key}}
        {{- end }}
        DEBUG = "true"
        HOSTNAME = "*"
        SSH_USERNAME = "vagrant"
        CONSUL_URL = "${config.consul_url}"
        NOMAD_URL = "${config.nomad_url}"
        BACKEND = "qemu"
        {{- range service "vmck-imghost" }}
          QEMU_IMAGE_URL = "http://{{.Address}}:{{.Port}}/cluster-master.qcow2.tar.gz"
        {{- end }}
        EOF
        destination = "local/vmck.env"
        env = true
      }
      resources {
        memory = 350
        cpu = 350
        network {
          port "http" {
            static = 9999
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
        DRONE_GITHUB_CLIENT_ID = "${config.ci_github_client_id}"
        DRONE_GITHUB_CLIENT_SECRET = "${config.ci_github_client_secret}"
        DRONE_USER_FILTER = "${config.ci_github_user_filter}"
        DRONE_USER_CREATE = "username:${config.ci_github_initial_admin_username},admin:true"
        DRONE_SERVER_HOST = "jenkins.${liquid_domain}"
        DRONE_SERVER_PROTO = "${config.liquid_http_protocol}"
        DRONE_RUNNER_CAPACITY = "2"
      }
      template {
        data = <<EOF
          {{- range service "vmck" }}
            DRONE_RUNNER_ENVIRON="VMCK_IP:{{.Address}},VMCK_PORT:{{.Port}}"
          {{- end }}
        EOF
        destination = "local/drone.env"
        env = true
      }
      resources {
        memory = 250
        cpu = 150
        network {
          port "http" {}
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
