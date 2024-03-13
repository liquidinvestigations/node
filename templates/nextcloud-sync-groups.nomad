job "nextcloud-sync-groups" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 99

  parameterized {
      payload = "forbidden"
    }

  group "sync-groups" {
    task "script" {
      leader = true

      driver = "raw_exec"

      config {
        command = "bash"
        args    = [
                "local/sync-groups.sh",
                ]
      }

      template {
        left_delimiter = "DELIMITER_L"
        right_delimiter = "DELIMITER_R"
        destination = "local/sync-groups.sh"
        perms = "755"
        data = <<-EOF
        {% include 'scripts/sync-nextcloud-groups.sh' %}
        EOF
      }
    }
  }
}