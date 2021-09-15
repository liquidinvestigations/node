job "liquid-createuser" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 60

  parameterized {
    meta_required = ["USERNAME"]
    }

  group "createuser" {
    task "script" {
      leader = true

      driver = "raw_exec"

      config {
        command = "sh"
        args    = ["local/createuser.sh"]
      }

      template {
        destination = "local/createuser.sh"
        perms = "755"
        data = <<-EOF
          #!/bin/sh
          set -ex
          ${exec_command('hoover:search', './manage.py', 'createuser', '${NOMAD_META_USERNAME}')}  
        EOF
      }
    }
  }
}