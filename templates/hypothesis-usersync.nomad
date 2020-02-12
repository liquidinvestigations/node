job "hypothesis-usersync" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 60

  periodic {
    cron = "*/5 * * * *"
    prohibit_overlap = true
  }

  group "usersync" {
    task "script" {
      leader = true

      # Constraint required to ensure this, the hypothesis and the liquid-core containers all run on the same machine.
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "raw_exec"

      config {
        command = "sh"
        args    = ["local/usersync.sh"]
      }

      template {
        destination = "local/usersync.sh"
        perms = "755"
        data = <<-EOF
          #!/bin/sh
          set -ex

          core_container_id="$(docker ps -q -f label=liquid_task=liquid-core)"
          hypothesis_pg_container_id="$(docker ps -q -f label=liquid_task=hypothesis-pg)"
          hypothesis_container_id="$(docker ps -q -f label=liquid_task=hypothesis-h)"

          liquid_core_users="$(docker exec $core_container_id /local/users.py)"
          hypothesis_users="$(docker exec $hypothesis_pg_container_id psql -U hypothesis hypothesis -c 'COPY (SELECT username FROM "user") TO stdout WITH CSV;')"
          docker exec $hypothesis_container_id /local/usersync.py "$liquid_core_users" "$hypothesis_users"
        EOF
      }
    }
  }
}
