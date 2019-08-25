{% from '_lib.hcl' import authproxy_group, task_logs with context -%}

job "hypothesis" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  group "db" {
    task "pg" {
      driver = "docker"
      config {
        image = "postgres:9.4-alpine"
        volumes = [
          "${liquid_volumes}/hypothesis/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "hypothesis-pg"
        }
        port_map {
          pg = 5432
        }
      }
      template {
        data = <<-EOF
          POSTGRES_USER = "hypothesis"
          POSTGRES_DATABASE = "hypothesis"
          {{- with secret "liquid/hypothesis/hypothesis.postgres" }}
            POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
          EOF
        destination = "local/postgres.env"
        env = true
      }
      resources {
        memory = 350
        network {
          mbits = 1
          port "pg" {}
        }
      }
      service {
        name = "hypothesis-pg"
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

    task "es" {
      driver = "docker"
      config {
        image = "hypothesis/elasticsearch:latest"
        args = ["/bin/sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data && echo chown done && /usr/local/bin/docker-entrypoint.sh"]
        volumes = [
          "${liquid_volumes}/hypothesis/es/data:/usr/share/elasticsearch/data",
        ]
        port_map {
          es = 9200
        }
        labels {
          liquid_task = "hypothesis-es"
        }
      }
      env {
        discovery.type = "single-node"
      }
      resources {
        memory = 5000
        network {
          mbits = 1
          port "es" {}
        }
      }
      service {
        name = "hypothesis-es"
        port = "es"
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/_cluster/health"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    task "rabbitmq" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "rabbitmq:3.6-management-alpine"
        volumes = [
          "${liquid_volumes}/hypothesis/rabbitmq/rabbitmq:/var/lib/rabbitmq",
        ]
        port_map {
          amqp = 5672
          management = 15672
        }
        labels {
          liquid_task = "hypothesis-rabbitmq"
        }
      }
      resources {
        memory = 700
        cpu = 150
        network {
          mbits = 1
          port "amqp" {}
        }
      }
      service {
        name = "hypothesis-rabbitmq"
        port = "amqp"
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

  group "h" {
    task "hypothesis" {
      driver = "docker"
      config = {
        image = "hypothesis/hypothesis"
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
      }
      template {
        data = <<-EOF
          #!/bin/sh -ex
          bin/hypothesis init
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

          APP_URL = "https://hypothesis.${liquid_domain}"
          CLIENT_URL = "https://client.hypothesis.${liquid_domain}"
          PROXY_AUTH = "true"
          AUTHORITY = ${liquid_domain|tojson}
          {{- with secret "liquid/hypothesis/hypothesis.secret_key" }}
            SECRET_KEY = {{.Data.secret_key|toJSON}}
          {{- end }}

          {{- if keyExists "liquid_debug" }}
          PYRAMID_DEBUG_ALL = "true"
          PYRAMID_RELOAD_TEMPLATES = "true"
          {{- end }}

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
                  "--username", username,
                  "--authority", authority,
              ])
          EOF
          perms = "755"
          destination = "local/usersync.py"
      }
      resources {
        memory = 1000
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
      }
    }
  }

  ${- authproxy_group(
      'hypothesis',
      host='hypothesis.' + liquid_domain,
      upstream='hypothesis',
      user_header_template="acct:{}@" + liquid_domain,
    ) }
}
