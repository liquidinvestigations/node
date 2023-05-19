{% from '_lib.hcl' import shutdown_delay, group_disk, task_logs, continuous_reschedule with context -%}

job "nextcloud-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "maria" {
    ${ group_disk() }
    ${ continuous_reschedule() }
    task "maria" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      affinity {
        attribute = "{% raw %}${meta.liquid_large_databases}{% endraw %}"
        value     = "true"
        weight    = 100
      }

      driver = "docker"
      ${ shutdown_delay() }
      config {
        image = "mariadb:10.11"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud/mysql:/var/lib/mysql",
        ]
        labels {
          liquid_task = "nextcloud-maria"
        }
        port_map {
          maria = 3306
        }
        memory_hard_limit = 750
      }
      template {
        data = <<-EOF
        MYSQL_RANDOM_ROOT_PASSWORD = "yes"
        MYSQL_DATABASE = "nextcloud"
        MYSQL_USER = "nextcloud"
        {{ with secret "liquid/nextcloud/nextcloud.maria" }}
          MYSQL_PASSWORD = {{.Data.secret_key | toJSON }}
        {{ end }}
        EOF
        destination = "local/maria.env"
        env = true
      }
      resources {
        cpu = 200
        memory = 250
        network {
          mbits = 1
          port "maria" {
            static = 8767
          }
        }
      }
      service {
        name = "nextcloud-maria"
        port = "maria"
        tags = ["fabio-:${config.port_nextcloud_maria} proto=tcp"]
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "minio-nextcloud" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "minio-nextcloud" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "${config.image('minio')}"
        entrypoint = ["/bin/sh", "-c"]
        args = ["mkdir -p /data/nextcloud && /usr/bin/docker-entrypoint.sh minio server --console-address :9001 /data"]
        port_map {
          s3 = 9000
          console = 9001
        }
        labels {
          liquid_task = "nextcloud-minio"
        }
        memory_hard_limit = 5000
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud/minio:/data",
        ]
      }

      env {
        MINIO_UPDATE = "off"
        MINIO_API_REQUESTS_MAX = "600"
        MINIO_API_REQUESTS_DEADLINE = "2m"
        GOMAXPROCS = "20"
      }

      resources {
        memory = 1500
        cpu = 1000
        network {
          mbits = 1
          port "s3" { static = 9005 }
          port "console" { static = 9006 }
        }
      }

      template {
        data = <<EOF
          {{- with secret "liquid/nextcloud/minio.user" }}
              MINIO_ROOT_USER = {{.Data.secret_key | toJSON }}
          {{- end }}
          {{- with secret "liquid/nextcloud/minio.password" }}
              MINIO_ROOT_PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/minio.env"
        env = true
      }

      service {
        name = "nextcloud-minio-s3"
        port = "s3"
        tags = ["fabio-:${config.port_nextcloud_minio} proto=tcp"]

        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }

      service {
        name = "nextcloud-minio-console"
        port = "console"
        tags = ["fabio-/nextcloud_minio_console strip=/nextcloud_minio_console"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
  group "minio-nextcloud-ext" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "minio-nextcloud-ext" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "${config.image('minio')}"
        entrypoint = ["/bin/sh", "-c"]
        args = ["mkdir -p /data/nextcloud && /usr/bin/docker-entrypoint.sh minio server --console-address :9001 /data"]
        port_map {
          s3 = 9000
          console = 9001
        }
        labels {
          liquid_task = "nextcloud-ext-minio"
        }
        memory_hard_limit = 5000
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud/minio-ext:/data",
        ]
      }

      env {
        MINIO_UPDATE = "off"
        MINIO_API_REQUESTS_MAX = "600"
        MINIO_API_REQUESTS_DEADLINE = "2m"
        GOMAXPROCS = "20"
      }

      resources {
        memory = 1500
        cpu = 1000
        network {
          mbits = 1
          port "s3" { static = 9007 }
          port "console" { static = 9008 }
        }
      }

      template {
        data = <<EOF
          {{- with secret "liquid/nextcloud/minioext.user" }}
              MINIO_ROOT_USER = {{.Data.secret_key | toJSON }}
          {{- end }}
          {{- with secret "liquid/nextcloud/minioext.password" }}
              MINIO_ROOT_PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/minio.env"
        env = true
      }

      service {
        name = "nextcloud-ext-minio-s3"
        port = "s3"
        tags = ["fabio-:${config.port_nextcloud_minio_ext} proto=tcp"]

        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }

      service {
        name = "nextcloud-ext-minio-console"
        port = "console"
        tags = ["fabio-/nextcloud_minio_console strip=/nextcloud_minio_console"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }
}