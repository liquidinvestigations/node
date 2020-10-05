{% from '_lib.hcl' import shutdown_delay, authproxy_group, continuous_reschedule, set_pg_password_template, task_logs, group_disk with context -%} 

job "newsleak-deps" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} } 

  group "newsleak-pg" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "newsleak-pg" {
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

      config {
        image = "postgres:9.6"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/newsleak/pg/data:/var/lib/postgresql/data"
        ]
        labels {
          liquid_task = "newsleak-pg"
        }
        port_map {
          pg = 5432
        }
        # 128MB, the default postgresql shared_memory config
        shm_size = 134217728
        memory_hard_limit = 1200
      }
      template {
        data = <<EOF
          POSTGRES_PASSWORD=newsreader 
          POSTGRES_USER=newsreader 
          POSTGRES_DB=newsleak
        EOF
        destination = "local/postgres.env"
        env = true
      }

      ${ set_pg_password_template('newsreader') }
      
      resources {
        memory = 350
        network {
          mbits = 1
          port "pg" {}
        }
      }
      service {
        name = "newsleak-pg"
        port = "pg"
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

  group "newsleak-es" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "newsleak-es" {
      ${ task_logs() }
      driver = "docker"
        config {
          image = "elasticsearch:2.4.6"
          #args = ["/bin/sh", "-c", "chown 1000:1000 /usr/share/elasticsearch/data && echo chown done && /docker-entrypoint.sh && echo entrypoint done"]
          volumes = [
            "{% raw %}${meta.liquid_volumes}{% endraw %}/newsleak/es/data:/usr/share/elasticsearch/data"
          ]
          port_map {
            http = 9200
            transport = 9300
          }
          labels {
            liquid_task = "newsleak-es"
          }
          ulimit {
            memlock = "-1"
            nofile = "65536"
            nproc = "8192"
          }
        }
              service {
        name = "newsleak-es-http"
        port = "http"
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/_cluster/health"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }

      service {
        name = "newsleak-es-transport"
        port = "transport"
        check {
          name = "transport"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }

      resources {
        cpu = 600
        memory = ${config.elasticsearch_memory_limit}
        network {
          mbits = 1
          port "http" {}
          port "transport" {}
        }
      }
    }
  }

  group "newsleak-ner" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "newsleak-ner" {
      ${ task_logs() }
      driver = "docker"
      config {
        image = "uhhlt/newsleak-ner:v1.0"
        port_map {
          ner = 5001
        }
        labels {
          liquid_task = "newsleak-ner"
        }
      }
      service {
        name = "newsleak-ner"
        port = "ner"
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    
      resources {
        cpu = 600
        memory = 350
        network {
          mbits = 1
          port "ner" {}
        }
      }
    }
  }

}