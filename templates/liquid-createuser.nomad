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
        destination = "local/create_rocket_user.py"
        perms = "755"
        data = <<-EOF
{% include 'scripts/create_rocket_user.py' %}
        EOF
      }

      template {
        destination = "local/createuser.sh"
        perms = "755"
        data = <<-EOF
        {% include 'scripts/createuser.sh' %}
        EOF
      }
    }
  }
}
