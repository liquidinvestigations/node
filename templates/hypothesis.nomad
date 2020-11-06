{% from '_lib.hcl' import shutdown_delay, authproxy_group_old, task_logs, group_disk, continuous_reschedule with context -%}

job "hypothesis" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  group "hypothesis" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "hypothesis" {
      ${ task_logs() }
      # Constraint required for hypothesis-usersync
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config = {
        image = "${config.image('hypothesis-h')}"
        entrypoint = ["/local/entrypoint"]
        labels {
          liquid_task = "hypothesis-h"
        }
        volumes = [
          ${hypothesis_h_h_repo}
          ${hypothesis_h_conf_repo}
        ]
        port_map {
          http = 5000
        }
        memory_hard_limit = ${3 * config.hypothesis_memory_limit}
      }

      template {
        data = <<-EOF
          import os
          from h import cli, models
          request = cli.bootstrap(os.environ['APP_URL'])
          authclient = request.db.query(models.AuthClient).filter_by(name='liquid').one_or_none()
          if authclient:
              id_ = authclient.id
          else:
              authclient = models.AuthClient(
                  name='liquid',
                  authority="hypothesis.${liquid_domain}",
                  redirect_uri="${config.liquid_http_protocol}://hypothesis.${liquid_domain}/app.html",
                  grant_type=models.auth_client.GrantType.authorization_code,
                  response_type=models.auth_client.ResponseType.code,
                  trusted=True,
              )
              request.db.add(authclient)
              request.db.flush()
              id_ = authclient.id
              request.tm.commit()
          print(id_)
          EOF
        destination = "local/get_client_oauth_id.py"
      }

      template {
        data = <<-EOF
          #!/bin/sh -ex
          bin/hypothesis init
          export CLIENT_OAUTH_ID=$(python /local/get_client_oauth_id.py)
          exec init-env supervisord -c conf/supervisord.conf
          EOF
        destination = "local/entrypoint"
        perms = "755"
      }

      template {
        data = <<-EOF
          {{- range service "hypothesis-es" }}
          ELASTICSEARCH_URL = "http://{{.Address}}:{{.Port}}"
          {{- end }}

          {{- range service "hypothesis-pg" }}
            DATABASE_URL = "postgresql://hypothesis:
            {{- with secret "liquid/hypothesis/hypothesis.postgres" -}}
              {{.Data.secret_key }}
            {{- end -}}
            @{{.Address}}:{{.Port}}/hypothesis"
          {{- end }}

          {{- range service "hypothesis-rabbitmq" }}
          BROKER_URL = "amqp://guest:guest@{{.Address}}:{{.Port}}//"
          {{- end }}

          APP_URL = "${config.liquid_http_protocol}://hypothesis.${liquid_domain}"
          CLIENT_URL = "${config.liquid_http_protocol}://client.hypothesis.${liquid_domain}"
          CLIENT_RPC_ALLOWED_ORIGINS = "${config.liquid_http_protocol}://client.hypothesis.${liquid_domain} ${config.liquid_http_protocol}://hypothesis.${liquid_domain} ${config.liquid_http_protocol}://dokuwiki.${liquid_domain} ${config.liquid_http_protocol}://hoover.${liquid_domain} ${config.liquid_http_protocol}://${liquid_domain}"
          PROXY_AUTH = "true"
          AUTHORITY = ${liquid_domain|tojson}
          {{- with secret "liquid/hypothesis/hypothesis.secret_key" }}
            SECRET_KEY = {{.Data.secret_key|toJSON}}
          {{- end }}

          {{- if keyExists "liquid_debug" }}
          PYRAMID_DEBUG_ALL = "true"
          PYRAMID_RELOAD_TEMPLATES = "true"
          {{- end }}

          LIQUID_URL = "${config.liquid_http_protocol}://${liquid_domain}"
          LIQUID_TITLE = "${config.liquid_title}"
          EOF

        destination = "local/h.env"
        env = true
      }

      template {
        data = <<-EOF
          #!/usr/bin/env python3
          import sys, subprocess, secrets
          class SafeString(str):
              def __repr__(self):
                  return "***"
          def run(args):
              print("+", args, flush=True)
              subprocess.run(args)
          authority = ${liquid_domain|tojson}
          [liquid_users_txt, h_users_txt] = sys.argv[1:]
          liquid_users = set(liquid_users_txt.split())
          h_users = set(h_users_txt.split())
          for username in liquid_users - h_users:
              password = SafeString(secrets.token_urlsafe(32))  # 256 bits
              run([
                  "bin/hypothesis", "user", "add",
                  "--username", username,
                  "--authority", authority,
                  "--email", f"{username}@${liquid_domain}",
                  "--password", password,
              ])
          for username in h_users - liquid_users:
              run([
                  "bin/hypothesis", "user", "delete",
                  username,
                  "--authority", authority,
              ])
          EOF
          perms = "755"
          destination = "local/usersync.py"
      }

      resources {
        memory = ${config.hypothesis_memory_limit}
        cpu = 200
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "hypothesis"
        port = "http"
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/login"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["hypothesis.${liquid_domain}"]
          }
        }
        check {
          name = "check-workers-script"
          type = "script"
          command = "/bin/sh"
          args = ["-c", "ps aux -o comm,args | grep '^python .* celery worker'"]
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "client" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "nginx" {
      ${ task_logs() }

      driver = "docker"
      config = {
        image = "${config.image('h-client')}"
        port_map {
          http = 80
        }
        labels {
          liquid_task = "hypothesis-client"
        }
        memory_hard_limit = 100
      }

      template {
        data = <<-EOF
          LIQUID_DOMAIN = ${liquid_domain|tojson}
          LIQUID_HTTP_PROTO = ${config.liquid_http_protocol|tojson}
          EOF
        destination = "local/bake.env"
        env = true
      }

      resources {
        memory = 10
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "hypothesis-client"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:client.hypothesis.${liquid_domain}",
        ]
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
