{% from '_lib.hcl' import set_pg_password_template, shutdown_delay, authproxy_group, task_logs, group_disk, continuous_reschedule with context -%}

job "bbb" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "bbb" {
    ${ group_disk() }
    ${ continuous_reschedule() }

    task "bbb-gl" {
      ${ task_logs() }
      leader = false

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

      template {
        data = <<-EOF
        {{- with secret "liquid/bbb/bbb.postgres" }}
        DATABASE_URL = "postgres://greenlight:{{.Data.secret_key | toJSON }}@{{env "attr.unique.network.ip-address"}}:${config.port_bbb_pg}/greenlight_production"
        {{- end }}
        REDIS_URL = "redis://{{ env "attr.unique.network.ip-address"}}:${config.port_bbb_redis}"
        BIGBLUEBUTTON_ENDPOINT = "${config.bbb_endpoint}"
        BIGBLUEBUTTON_SECRET = "${config.bbb_secret}"
        {{- with secret "liquid/bbb/bbb.secret_key_base" }}
        SECRET_KEY_BASE = {{.Data.secret_key | toJSON }}
        {{- end }}
        RELATIVE_URL_ROOT = "/"
        {{- with secret "liquid/bbb/gloauth.oauth2" }}
        OPENID_CONNECT_CLIENT_ID = {{.Data.client_id | toJSON }}
        OPENID_CONNECT_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
        {{- end }}
        OPENID_CONNECT_ISSUER="${config.liquid_http_protocol}://${liquid_domain}"
        OPENID_CONNECT_REDIRECT="${config.liquid_http_protocol}://bbb.${liquid_domain}/"
        EOF
        destination = "local/greenlight.env"
        env = true
      }

      config {
        image = "${config.image('bbb-gl')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/bbb/greenlight/data/:/usr/src/app/storage/",
        ]
        port_map {
          bbb-gl = 3000
        }
        labels {
          liquid_task = "bbb_greenlight"
        }
        memory_hard_limit = 2000
      }

      resources {
        memory = 450
        cpu = 150
        network {
          mbits = 1
          port "bbb-gl" {}
        }
      }

      service {
        name = "bbb-gl"
        port = "bbb-gl"
        tags = ["fabio-:${config.port_bbb_gl} proto=tcp"]
        check {
          name = "bbb-gl"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}
