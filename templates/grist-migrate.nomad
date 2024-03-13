{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "grist-migrate" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 98

  group "minio-bucket" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "minio-bucket" {
      leader = true

      ${ task_logs() }

      driver = "docker"
      config {
        image = "${config.image('mc2024')}"
        entrypoint = ["sh"]
        args = ["/local/migrate.sh"]
        labels {
          liquid_task = "grist-migrate"
        }
      }
      template {
        data = <<-EOF
          {{- with secret "liquid/grist/minio.user" }}
              S3_USER={{.Data.secret_key | toJSON }}
          {{- end }}
          {{- with secret "liquid/grist/minio.password" }}
              S3_PASS={{.Data.secret_key | toJSON }}
          {{- end }}
          S3_HOST={{env "attr.unique.network.ip-address" }}
          S3_PORT=${config.port_grist_s3}
        EOF
        destination = "local/env.sh"
        env = true
      }
      template {
        data = <<-EOFF
          set -ex
          mc config host rm local;
          mc config host add --quiet --api s3v4 local http://$S3_HOST:$S3_PORT $S3_USER $S3_PASS;
          mc ping local --count 1;
          mc mb --ignore-existing --with-versioning  local/grist-docs
        EOFF
        destination = "local/migrate.sh"
      }
    }
  }
}
