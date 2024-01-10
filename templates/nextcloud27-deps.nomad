{% from '_lib.hcl' import shutdown_delay, group_disk, task_logs, continuous_reschedule with context -%}

job "nextcloud27-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98

  group "nextcloud27-maria" {
    ${ group_disk() }
    ${ continuous_reschedule() }
    task "nextcloud27-maria" {
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
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud27/mysql:/var/lib/mysql",
        ]
        labels {
          liquid_task = "nextcloud27-maria"
        }
        port_map {
          maria = 3306
        }
        memory_hard_limit = 750
      }
      template {
        data = <<-EOF
        MYSQL_RANDOM_ROOT_PASSWORD = "yes"
        MYSQL_DATABASE = "nextcloud27"
        MYSQL_USER = "nextcloud27"
        {{ with secret "liquid/nextcloud27/nextcloud.maria" }}
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
            static = 8769
          }
        }
      }
      service {
        name = "nextcloud27-maria"
        port = "maria"
        tags = ["fabio-:${config.port_nextcloud27_maria} proto=tcp"]
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

  group "minio-nextcloud27" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "minio-nextcloud27" {
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
          liquid_task = "nextcloud27-minio"
        }
        memory_hard_limit = 5000
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud27/minio:/data",
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
          {{- with secret "liquid/nextcloud27/minio.user" }}
              MINIO_ROOT_USER = {{.Data.secret_key | toJSON }}
          {{- end }}
          {{- with secret "liquid/nextcloud27/minio.password" }}
              MINIO_ROOT_PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
        EOF
        destination = "local/minio.env"
        env = true
      }

      service {
        name = "nextcloud27-minio-s3"
        port = "s3"
        tags = ["fabio-:${config.port_nextcloud27_minio} proto=tcp"]

        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }

      service {
        name = "nextcloud27-minio-console"
        port = "console"
        tags = ["fabio-/nextcloud27_minio_console strip=/nextcloud27_minio_console"]
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

   # using the built-in code server for testing for now

   group "nextcloud27-office" {
     ${ group_disk() }
     ${ continuous_reschedule() }
     network {
       port "collabora" {
         to = 9980
       }
     }
     task "nextcloud27-collabora" {
       ${ task_logs() }

       driver = "docker"
       ${ shutdown_delay() }
       config {
         image = "collabora/code:23.05.5.4.1"
         labels {
           liquid_task = "nextcloud27-collabora"
         }
         memory_hard_limit = 750
         ports = ["collabora"]
       }
       env {
         aliasgroup1 = "${config.liquid_http_protocol}://nextcloud-instance-2.${config.liquid_domain}"
         extra_params = "--o:ssl.enable=false --o:ssl.termination=true"
       }
       resources {
         cpu = 500
         memory = 500
       }
     }
     service {
       name = "nextcloud27-collabora"
       port = "collabora"
       tags = ["fabio-:9949 proto=tcp"]
       check {
         name = "tcp"
         initial_status = "critical"
         type = "tcp"
         interval = "${check_interval}"
         timeout = "${check_timeout}"
       }
     }
   }

  group "nextcloud27-onlyoffice" {
    ${ group_disk() }
    ${ continuous_reschedule() }
    network {
      port "http" {
        to = 80
      }
    }

    task "nextcloud27-onlyoffice" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      ${ shutdown_delay() }
      config {
        image = "onlyoffice/documentserver:latest"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud27/onlyoffice/document_data:/var/www/onlyoffice/Data",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud27/onlyoffice/document_log:/var/log/onlyoffice",
        ]
        ports = [
          "http",
        ]
        labels {
          liquid_task = "nextcloud27-onlyoffice"
        }
        memory_hard_limit = 750
      }

      env {
        JWT_SECRET = "secret"
      }

      resources {
        cpu = 500
        memory = 500
      }

      service {
        name = "nextcloud27-onlyoffice"
        port = "http"
        tags = ["fabio-:${config.port_onlyoffice} proto=tcp"]
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
}
