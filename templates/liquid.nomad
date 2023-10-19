{% from '_lib.hcl' import continuous_reschedule, group_disk, task_logs -%}

job "liquid" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  group "core" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    # network {
    #   mode = "bridge"

    #   port "core-http" {
    #     static = 8000
    #     to     = 8000
    #   }
    # }

    # service {
    #   name = "cc-core-http"
    #   port = "core-http"
    #   connect {
    #     sidecar_service {}
    #   }
    # }

    task "core" {
      ${ task_logs() }

      # Constraint required for user sync
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "${config.image('liquid-core')}"
        volumes = [
          ${liquidinvestigations_core_repo}
          "{% raw %}${meta.liquid_volumes}{% endraw %}/liquid/core/var:/app/var",
        ]
        labels {
          liquid_task = "liquid-core"
        }
        port_map {
          http = 8000
        }

        memory_hard_limit = 2048
      }
      # used to auto-restart containers when running deploy, after you make a new commit
      env {
        __GIT_TAGS = "${liquidinvestigations_core_git}"
        {% if config.sentry_dsn_liquid_core %}
          SENTRY_DSN = "${config.sentry_dsn_liquid_core}"
          SENTRY_ENVIRONMENT = "${config.sentry_environment}"
          SENTRY_RELEASE = "${config.sentry_version_liquid_core}${config.sentry_release}"
        {% endif %}
      }

      template {
        data = <<-EOF
          LIQUID_HEALTHCHECK_INFO_FILE = "/local/healthcheck_info.json"
          DEBUG = {{key "liquid_debug" | toJSON }}
          {{- with secret "liquid/liquid/core.django" }}
            SECRET_KEY = {{.Data.secret_key | toJSON }}
          {{- end }}
          LIQUID_HTTP_PROTOCOL = "${config.liquid_http_protocol}"
          LIQUID_DOMAIN = "{{key "liquid_domain"}}"
          LIQUID_TITLE = "${config.liquid_title}"
          LIQUID_VERSION = "${config.liquid_version}"
          LIQUID_CORE_VERSION = "${config.liquid_core_version}"
          AUTH_STAFF_ONLY = "${config.auth_staff_only}"
          AUTH_AUTO_LOGOUT = "${config.auth_auto_logout}"
          LIQUID_2FA = "${config.liquid_2fa}"
          LIQUID_APPS = ${ config.liquid_apps | tojson | tojson}
          NOMAD_URL = "${config.nomad_url}"
          CONSUL_URL = "${config.consul_url}"
          AUTHPROXY_REDIS_URL = "redis://{{ env "attr.unique.network.ip-address" }}:${config.port_authproxy_redis}/"

          {% if config.enable_superuser_dashboards %}
          LIQUID_ENABLE_DASHBOARDS = "true"
          LIQUID_DASHBOARDS_PROXY_BASE_URL = "http://{{env "attr.unique.network.ip-address"}}:${config.port_lb}"
          LIQUID_DASHBOARDS_PROXY_NOMAD_URL = "http://{{env "attr.unique.network.ip-address"}}:4646"
          LIQUID_DASHBOARDS_PROXY_CONSUL_URL = "http://{{env "attr.unique.network.ip-address"}}:8500"
          {% endif %}
        EOF
        destination = "local/docker.env"
        env = true
      }

      template {
        data = <<-EOF
          #!/usr/bin/env python3
          import sys, os
          os.environ['DJANGO_SETTINGS_MODULE'] = 'liquidcore.site.settings'
          sys.path.append('/app')
          import django
          django.setup()
          from django.contrib.auth.models import User
          for u in User.objects.all():
              print(u.username)
          EOF
          perms = "755"
          destination = "local/users.py"
      }

      template {
        data = <<-EOF
${config.liquid_core_healthcheck_info}
          EOF
          destination = "local/healthcheck_info.json"
      }

      resources {
        memory = 200
        network {
          mbits = 1
          port "http" {
            static = 8768
          }
        }
      }

      service {
        name = "core"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:${liquid_domain}",
          "fabio-/_core strip=/_core",
        ]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["${liquid_domain}"]
          }
        }
      }
    }
  }

  {% if config.sentry_proxy_to_subdomain %}
  group "sentry-proxy-nginx" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "sentry-proxy-nginx" {
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
          http = 8080
        }
        labels {
          liquid_task = "sentry-proxy-nginx"
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

          tcp_nopush   on;
          server_names_hash_bucket_size 128;
          sendfile on;
          sendfile_max_chunk 4m;
          aio threads;
          limit_rate 66m;

          upstream sentry {
            server ${config.sentry_proxy_to_subdomain};
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

            location  / {
              proxy_pass http://sentry;
            }
          }
        }
        EOF
        destination = "local/nginx.conf"
      }

      service {
        name = "sentry-proxy-nginx"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:${'sentry.' + liquid_domain}",
        ]
        check {
          name = "ping"
          initial_status = "critical"
          type = "http"
          path = "/_ping"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["sentry.${liquid_domain}"]
          }
        }
        check_restart {
          limit = 5
          grace = "995s"
        }
      }
    }
  }
  {% endif %}

}
