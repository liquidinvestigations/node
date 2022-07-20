job "liquid-deleteuser" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 99

  parameterized {
    meta_required = ["USERNAME"]
    }

  group "deleteuser" {
    task "script" {
      leader = true

      driver = "raw_exec"

      config {
        command = "sh"
        args    = ["local/deleteuser.sh"]
      }

      template {
        destination = "local/delete_rocket_user.py"
        perms = "755"
        data = <<-EOF
{% include 'scripts/delete_rocket_user.py' %}
        EOF
      }

      template {
        destination = "local/deleteuser.sh"
        perms = "755"
        data = <<-EOF
        {% include 'scripts/deleteuser.sh' %}
        EOF
      }
    }
  }
}
