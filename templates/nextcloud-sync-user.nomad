job "nextcloud-sync-user" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 99

  parameterized {
      payload = "forbidden"
    }

  group "sync-user" {
    task "script" {
      leader = true

      driver = "raw_exec"

      config {
        command = "bash"
        args    = [
                "local/sync-user.sh",
                ]
      }

      template {
        left_delimiter = "DELIMITER_L"
        right_delimiter = "DELIMITER_R"
        destination = "local/sync-user.sh"
        perms = "755"
        data = <<-EOF
        {% include 'scripts/sync-nextcloud-users.sh' %}
        EOF
      }
    }
  }
}