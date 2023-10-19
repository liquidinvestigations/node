{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "matrix-migrate" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 98

  group "chown-data" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "chown-data" {
      leader = true

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "alpine"
        args = ["/bin/sh", "/local/run.sh"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/matrix/synapse-Z:/mount",
        ]
      }
      template {
        data = <<-EOFF
        mkdir -p /mount/files/ || true
        chown 991:991 /mount/ || true
        chown 991:991 /mount/files || true
        EOFF
        destination = "local/run.sh"
      }
    }
  }


  group "create-certificate" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "create-certificate" {
      leader = true

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      ${ task_logs() }

      driver = "docker"
      config {
        image = "alpine"
        args = ["/bin/sh", "/local/run.sh"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/matrix/oidc-selfhosted-certificate:/data",
        ]
      }
      template {
        data = <<-EOFF
        apk add openssl
        export DOMAIN=core-oidc.local

        if [ -f /data/ssl/certs/nginx-selfsigned.crt ]; then echo 'cert exists'; exit 0; fi

        mkdir -p /data/private /data/certs

        openssl req -x509 -nodes -days 3650 -subj "/C=CA/ST=QC/O=Company, Inc./CN=$DOMAIN" -addext "subjectAltName=DNS:$DOMAIN" -newkey rsa:2048 -keyout /data/private/nginx-selfsigned.key -out /data/certs/nginx-selfsigned.crt

        chmod -R a+rwx /data

        EOFF
        destination = "local/run.sh"
      }
    }
  }
}
