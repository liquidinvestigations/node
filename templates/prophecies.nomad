{% from '_lib.hcl' import shutdown_delay, task_logs, group_disk, continuous_reschedule with context -%}

job "prophecies" {
  datacenters = ["dc1"]
  type = "service"
  priority = 97

  group "prophecies" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "prophecies" {
      ${ task_logs() }

      # for the image uploads directory
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = -99
      }

      leader = true
      driver = "docker"
      config {
        image = "${config.image('prophecies')}"
        port_map {
          http = 8008
        }
        labels {
          liquid_task = "prophecies"
        }
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/prophecies/static:/code/prophecies/run/static",
        ]
        memory_hard_limit = 9999
        entrypoint = ["/bin/bash", "-ex"]
        args = ["/local/startup.sh"]
      }

      resources {
        cpu = 300
        memory = 250
        network {
          mbits = 1
          port "http" {}
        }
      }
      env {

        # DATABASE_URL = "postgres://postgres:postgres@db/prophecies"
        {% if config.liquid_debug %}
        DEBUG = "true"
        {% else %}
        DEBUG = "false"

        {% endif %}
        DJANGO_SETTINGS_MODULE = "prophecies.settings.production"
        # DJANGO_ADMIN_LOGIN = "true"
        # PROPHECIES_APP_LOGIN_URL = "/admin/login/?next=/"

        STATIC_URL="/static/"
        # SOCIAL_AUTH_LOGIN_URL = "/oauth2/sign_in"
        # SOCIAL_AUTH_LOGOUT_URL = "/oauth2/sign_out"
        SOCIAL_AUTH_PROVIDER_HOSTNAME="${config.liquid_core_url}"
        SOCIAL_AUTH_PROVIDER_USERNAME_FIELD="id"
        SOCIAL_AUTH_PROVIDER_GROUPS_FIELD="roles"
        SOCIAL_AUTH_PROVIDER_STAFF_GROUP="admin"
        SOCIAL_AUTH_PROVIDER_ACCESS_TOKEN_METHOD="POST"
        SECURE_PROXY_SSL_HEADER = "{% if config.https_enabled %}true{% else %}false{% endif %}"

      }

      template {
        data = <<-EOF
          DATABASE_URL = "postgresql://prophecies:
          {{- with secret "liquid/prophecies/prophecies.postgres" -}}
            {{.Data.secret_key }}
          {{- end -}}
          @{{ env "attr.unique.network.ip-address" }}:${config.port_prophecies_pg}/prophecies"

        {{- with secret "liquid/prophecies/app.auth.oauth2" }}
          SOCIAL_AUTH_PROVIDER_KEY = {{.Data.client_id | toJSON }}
          SOCIAL_AUTH_PROVIDER_SECRET = {{.Data.client_secret | toJSON }}
        {{- end }}

        {{- with secret "liquid/prophecies/session.secret" }}
          SECRET_KEY = {{.Data.secret_key | toJSON }}
        {{- end }}

        ALLOWED_HOSTS = "0.0.0.0,localhost,web,prophecies.${liquid_domain},{{ env "attr.unique.network.ip-address" }}"
        CSRF_TRUSTED_ORIGINS = "${config.liquid_http_protocol}://prophecies.${liquid_domain},http://{{ env "attr.unique.network.ip-address" }}"

        SOCIAL_AUTH_PROVIDER_PROFILE_URL =  "http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/accounts/profile?"
        SOCIAL_AUTH_PROVIDER_ACCESS_TOKEN_URL = "http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/o/token/"
        SOCIAL_AUTH_PROVIDER_AUTHORIZATION_URL = "${config.liquid_core_url}/o/authorize/"

        appName =  "Prophecies"
        avatarUrlTemplate = "${config.liquid_http_protocol}://prophecies.${liquid_domain}/static/favicon-32x32.png"
        loginAccountButton = "Liquid Login"
        orgName = "${config.liquid_title}"
        logoutUrl = "${config.liquid_core_url}/accounts/logout/?next=/"


        EOF

        destination = "local/prophecies-db.env"
        env = true
      }

      template {
        data = <<-EOF

        poetry run python manage.py collectstatic --noinput
        poetry run python manage.py migrate --noinput
        bash /local/write_settings.sh

        poetry run gunicorn prophecies.wsgi -b 0.0.0.0:8008

        EOF

        destination = "local/startup.sh"
      }

      template {
        data = <<-EOF
        set -ex

        USERNAME=$1

        (
        cat <<EOPY

        from django.contrib.auth.models import User
        u = User.objects.get(username='$USERNAME')
        u.is_superuser = True
        u.save()
        print(u, 'is now prophecies superuser')

        EOPY
        ) | make shell

        EOF

        destination = "local/elevate_superuser.sh"
      }


      template {
        data = <<-EOF
        set -ex

        (
        cat <<EOPY

        import os
        # on Constance update to v3, import will change to constance.models or something
        from constance.backends.database.models import Constance
        import prophecies
        for key in ['appName', 'avatarUrlTemplate', 'loginAccountButton', 'orgName', 'logoutUrl', 'version']:
            c, _ = Constance.objects.get_or_create(key=key)
            c.value = prophecies.VERSION if key == 'version' else os.getenv(key)
            c.save()
            print(c, key, 'setting was set to', os.getenv(key))

        EOPY
        ) | make shell

        EOF

        destination = "local/write_settings.sh"
      }

      service {
        name = "prophecies-web"
        port = "http"
        tags = ["fabio-:${config.port_prophecies_web} proto=tcp"]
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
        check_restart {
          limit = 5
          grace = "990s"
        }
      }
    }
  }

  group "prophecies-nginx" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "prophecies-nginx" {
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
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/prophecies/static:/static:ro",
        ]
        port_map {
          http = 9999
        }
        labels {
          liquid_task = "prophecies-nginx"
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
          default_type  application/octet-stream;
          include       /etc/nginx/mime.types;

          tcp_nopush   on;
          server_names_hash_bucket_size 128;
          sendfile on;
          sendfile_max_chunk 4m;
          aio threads;
          limit_rate 66m;

          upstream web {
            ip_hash;
            server {{ env "attr.unique.network.ip-address" }}:${config.port_prophecies_web};
          }

          server {
              location /static/ {
                  autoindex on;
                  alias /static/;
              }

              location / {
                  proxy_pass http://web/;
              }
              location /_ping {
                return 200 "healthy\n";
              }

              listen 9999;

              server_name "prophecies.{{key "liquid_domain"}}";

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

          }
        }
        EOF
        destination = "local/nginx.conf"
      }

      service {
        name = "prophecies-nginx"
        port = "http"
        tags = ["fabio-:${config.port_prophecies_nginx} proto=tcp"]
        check {
          name = "ping"
          initial_status = "critical"
          type = "http"
          path = "/_ping"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["prophecies.${liquid_domain}"]
          }
        }
        check_restart {
          limit = 5
          grace = "995s"
        }
      }
    }
  }


}
