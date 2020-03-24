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

          liquid_core_users="$(${exec_command('liquid:core', '/local/users.py')})"
          hypothesis_users="$(${exec_command('hypothesis:pg', 'psql', '-U', 'hypothesis', 'hypothesis', '-c', "'COPY (SELECT username FROM public.user) TO stdout WITH CSV;'")})"
          ${exec_command('hypothesis:hypothesis', '/local/usersync.py', '"$liquid_core_users"', '"$hypothesis_users"')}
        EOF
      }
    }
  }
}
