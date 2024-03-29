{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "rocketchat-migrate" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 98

  group "init-replica-set" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "init-replica-set" {
      leader = true

      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('rocketchat-mongo')}"
        args = ["bash", "/local/init-replica-set.sh"]
        labels {
          liquid_task = "rocketchat-mongo-init-replica-set"
        }
      }
      template {
        data = <<-EOFF
# Auto-generated by rocketchat migrate script
{% include 'rocketchat-init-replica-set.sh' %}
EOFF
        destination = "local/init-replica-set.sh"
      }
      template {
        data = <<-EOFFF
          MONGO_ADDRESS = {{env "attr.unique.network.ip-address" }}
          MONGO_PORT = ${config.port_rocketchat_mongo}
EOFFF
        destination = "local/liquid.env"
        env = true
      }
    }
  }
}
