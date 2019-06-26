{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "collection-${name}-db-in-vault" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 45

  group "db" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "db-in-vault" {
      ${ task_logs() }

      driver = "docker"
      config {
        image = "postgres:9.6"
        args =  ["sh", "-c", "/usr/local/bin/docker-entrypoint.sh && chmod 777 /local/db-in-vault.sh && /local/db-in-vault.sh" ]
        volumes = [
          "${liquid_volumes}/collections/${name}/pg/data:/var/lib/postgresql/data",
        ]
        labels {
          liquid_task = "db-${name}-in-vault"
        }
      }
      template {
        data = <<EOF
          POSTGRES_USER = "snoop"
          POSTGRES_DATABASE = "snoop"
          {{- with secret "liquid/collections/${name}/snoop.postgres" }}
            POSTGRES_PASSWORD = {{.Data.secret_key}}
          {{- end }}
        EOF
        destination = "local/postgres.env"
        env = true
      }
      template {
        data = <<-EOF
        #!/bin/sh
        set -ex
        pwd
        date
        service postgresql start
        if grep -Fq "$host all all all trust" $PGDATA/pg_hba.conf
        then
          psql -U snoop -c "ALTER USER snoop password '$POSTGRES_PASSWORD'"
          sed -i '$d' $PGDATA/pg_hba.conf
          sed -i '$d' $PGDATA/pg_hba.conf
          {
            echo
            echo "host all all all md5"
            echo
          } >> "$PGDATA/pg_hba.conf"
          echo changed password of database
        else
          echo "password already set"
        fi
        EOF
        destination = "local/db-in-vault.sh"
      }
    }
  }
}
