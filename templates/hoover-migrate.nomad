{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "hoover-migrate" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 45

  group "search" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "migrate" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('liquidinvestigations/hoover-search')}"
        args = ["./manage.py", "migrate"]
        volumes = [
          ${hoover_search_repo}
          "${liquid_volumes}/hoover-ui/build:/opt/hoover/ui/build",
        ]
        labels {
          liquid_task = "hoover-search-migrate"
        }
      }
      template {
        data = <<-EOF
          {{- if keyExists "liquid_debug" }}
            DEBUG={{key "liquid_debug"}}
          {{- end }}
          {{- with secret "liquid/hoover/search.django" }}
            SECRET_KEY={{.Data.secret_key | toJSON }}
          {{- end }}
          {{- range service "hoover-pg" }}
            HOOVER_DB=postgresql://search:search@{{.Address}}:{{.Port}}/search
          {{- end }}
          {{- range service "hoover-es" }}
            HOOVER_ES_URL=http://{{.Address}}:{{.Port}}
          {{- end }}
          HOOVER_HOSTNAME=hoover.{{key "liquid_domain"}}
          TIMESTAMP=${config.timestamp}
        EOF
        destination = "local/hoover.env"
        env = true
      }
    }
  }
}
