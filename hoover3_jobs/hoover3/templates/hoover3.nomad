{% from '_lib.hcl' import authproxy_group, continuous_reschedule, group_disk, task_logs with context -%}

job "hoover3" {
  datacenters = ["dc1"]
  type = "service"


  group "hoover-nginx" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "hoover-nginx" {
      ${ task_logs() }

      driver = "docker"

      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = -99
      }

      config {
        image = "nginx:1.19"
        args = ["bash", "/local/startup.sh"]
        port_map {
          http = 7777
        }
        labels {
          liquid_task = "hoover-nginx"
        }
        memory_hard_limit = 1024
        network_mode = "host"
      }

      resources {
        memory = 128
        network {
          mbits = 1
          port "http" {
            static = 7777
          }
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

        {% if config.liquid_debug %}
          error_log /dev/stderr debug;
        {% else %}
          error_log /dev/stderr info;
        {% endif %}

        worker_rlimit_nofile 8192;
        worker_processes 4;
        events {
          worker_connections 4096;
        }

        http {
          {% if config.liquid_debug %}
            access_log  /dev/stdout;
          {% else %}
            access_log  off;
          {% endif %}
          default_type  application/octet-stream;
          include       /etc/nginx/mime.types;

          tcp_nopush   on;
          server_names_hash_bucket_size 128;
          sendfile on;
          sendfile_max_chunk 4m;
          aio threads;
          limit_rate 66m;

          upstream hoover3demo {
            server 127.0.0.1:8080;
          }

          server {
            listen 7777 default_server;
            listen [::]:7777 default_server;

            listen 10.66.60.1:7777 default_server;
            root /hoover-ui;

            {% if config.liquid_debug %}
              server_name _;
            {% else %}
              server_name "hoover.{{key "liquid_domain"}}";
            {% endif %}

            proxy_http_version  1.1;
            proxy_cache_bypass  $http_upgrade;
            proxy_connect_timeout 159s;
            proxy_send_timeout   150;
            proxy_read_timeout   150;
            proxy_buffer_size    64k;
            proxy_buffers     16 32k;
            proxy_busy_buffers_size 64k;
            proxy_temp_file_write_size 64k;

            proxy_set_header Upgrade           $http_upgrade;
            proxy_set_header Connection        "upgrade";
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
            proxy_set_header X-Forwarded-Host  $host;
            proxy_set_header X-Forwarded-Port  $server_port;
            proxy_pass_request_headers      on;

            client_max_body_size 5M;

            location /_ping {
              return 200 "healthy\n";
            }

            # include /hoover-ui/nginx-routes.conf;
            location / {
              proxy_pass http://hoover3demo;
            }
          }
        }
        EOF
        destination = "local/nginx.conf"
      }

      service {
        name = "hoover3-nginx"
        port = "http"
        # tags = ["fabio-:17777 proto=tcp"]


      }
    }
  }


  ${- authproxy_group(
      'hoover3',
      host='hoover3.' + liquid_domain,
      upstream_port=7777,
      group='hoover',
      redis_id=15,
    ) }

}
