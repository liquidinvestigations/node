{% from '_lib.hcl' import continuous_reschedule, task_logs, group_disk with context -%}

job "hoover-nginx" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

  group "hoover-nginx" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "hoover-nginx" {
      ${ task_logs() }

      driver = "docker"

      config {
        image = "nginx:1.19"
        args = ["bash", "/local/startup.sh"]
        port_map {
          http = 8080
        }
        labels {
          liquid_task = "hoover-nginx"
        }
        memory_hard_limit = 1024
      }

      resources {
        memory = 128
        network {
          mbits = 1
          port "http" {}
        }
      }

      template {
        data = <<-EOF
        #!/bin/bash
        set -ex

        cat /local/nginx.conf
        nginx -c /local/nginx.conf
        EOF
        env = false
        destination = "local/startup.sh"
      }

      template {
        data = <<-EOF

        daemon off;
        error_log /dev/stdout info;
        worker_rlimit_nofile 8192;
        worker_processes 4;
        events {
          worker_connections 4096;
        }

        http {
          access_log  off;
          tcp_nopush   on;
          server_names_hash_bucket_size 128;
          sendfile on;
          sendfile_max_chunk 4m;
          aio threads;

          upstream fabio {
            server {{env "attr.unique.network.ip-address"}}:9990;
          }

          server {
            listen 8080 default_server;
            listen [::]:8080 default_server;

            {% if config.liquid_debug %}
              server_name _;
            {% else %}
              server_name "hoover.{{key "liquid_domain"}}";
            {% endif %}

            proxy_http_version  1.1;
            proxy_cache_bypass  $http_upgrade;

            proxy_set_header Upgrade           $http_upgrade;
            proxy_set_header Connection        "upgrade";
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host  $host;
            proxy_set_header X-Forwarded-Port  $server_port;
            proxy_pass_request_headers      on;

            location /_ping {
              return 200 "healthy\n";
            }

            location  ~ ^/(api|admin|accounts|static) {
              rewrite ^/(api|admin|accounts|static)(.*) /hoover-search/$1$2 break;
              proxy_pass http://fabio;
            }

            location  / {
              proxy_pass http://fabio/hoover-ui;
            }
          }
        }
        EOF
        destination = "local/nginx.conf"
      }

      service {
        name = "hoover-nginx"
        port = "http"
        check {
          name = "ping"
          initial_status = "critical"
          type = "http"
          path = "/_ping"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["hoover.${liquid_domain}"]
          }
        }
        check_restart {
          limit = 3
          grace = "95s"
        }
      }
    }
  }

  {% if not config.hoover_ui_override_server %}
  group "hoover-ui" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "hoover-ui" {
      leader = true

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('hoover-ui')}"
        volumes = [
          ${hoover_ui_src_repo}
          ${hoover_ui_pages_repo}
          ${hoover_ui_styles_repo}
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover-ui/build:/opt/hoover/ui/build",
        ]
        port_map {
          http = 8000
        }
        labels {
          liquid_task = "hoover-ui"
        }
        args = ["sh", "/local/startup.sh"]
        memory_hard_limit = 3000
      }

      template {
        data = <<-EOF
        #!/bin/sh
        set -ex
        cp -v /local/.env.local .

        {% if config.liquid_debug %}
          exec npm run prod # dev
        {% else %}
          exec npm run prod
        {% endif %}
        EOF
        env = false
        destination = "local/startup.sh"
      }

      template {
        data = <<-EOF
          NEXT_PUBLIC_HOOVER_HYPOTHESIS_URL="${config.liquid_http_protocol}://hypothesis.${config.liquid_domain}/embed.js"
          API_URL = "http://{{env "attr.unique.network.ip-address"}}:9990/hoover-search"
        EOF
        env = true
        destination = "local/.env.local"
      }

      resources {
        memory = 900
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "hoover-ui"
        port = "http"
        tags = ["fabio-/hoover-ui strip=/hoover-ui"]
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
  {% endif %}
}
