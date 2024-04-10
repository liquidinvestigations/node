{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "bbb-migrate" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 98

  group "bbb-pg-migrate" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "bbb-pg-migrate" {
      leader = true

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('bbb-pg-15')}"
        args = ["/bin/sh", "/local/run.sh"]
        volumes = [
        ]
      }

        // DATABASE_URL = "postgres://greenlight:{{.Data.secret_key | toJSON }}@{{env "attr.unique.network.ip-address"}}:${config.port_bbb_pg}/greenlight_production"
      template {
        data = <<-EOF
        export BLOCK_RECORD=$(cat <<-END
            update rooms_configurations
            set value=false
            from meeting_options
            where meeting_options.id=rooms_configurations.meeting_option_id
            and meeting_options.name='record';
END
)
        export FORCE_LOGGED_IN_USERS=$(cat <<-END
            update rooms_configurations
            set value=true
            from meeting_options
            where meeting_options.id=rooms_configurations.meeting_option_id
            and meeting_options.name='glRequireAuthentication';
END
)
        {{- with secret "liquid/bbb/bbb.postgres" }}
        export PGPASSWORD={{.Data.secret_key | toJSON }}
        psql -p ${config.port_bbb_pg} \
          -h {{env "attr.unique.network.ip-address"}} \
          -U greenlight greenlight_production <<-END
            $BLOCK_RECORD
            $FORCE_LOGGED_IN_USERS
END
        {{- end }}
        EOF
        destination = "local/run.sh"
      }
    }
  }

}
