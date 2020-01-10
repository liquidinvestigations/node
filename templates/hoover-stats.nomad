{% from '_lib.hcl' import promtail_task with context -%}

job "hoover-stats" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  group "es" {
    task "es" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"

      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch:6.8.3"
        args = ["/bin/sh", "-c", "chown 1000:1000 /usr/share/elasticsearch/data && echo chown done && /usr/local/bin/docker-entrypoint.sh"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/hoover/stats/es:/usr/share/elasticsearch/data",
        ]
        port_map {
          http = 9200
        }
        labels {
          liquid_task = "hoover-stats"
        }
        ulimit {
          memlock = "-1"
          nofile = "65536"
          nproc = "8192"
        }
      }

      env {
        xpack.license.self_generated.type = "basic"
        xpack.monitoring.collection.enabled = "true"
        xpack.monitoring.collection.interval = "30s"
        xpack.monitoring.collection.cluster.stats.timeout = "30s"
        xpack.monitoring.collection.node.stats.timeout = "30s"
        xpack.monitoring.collection.index.stats.timeout = "30s"
        xpack.monitoring.collection.index.recovery.timeout = "30s"
        xpack.monitoring.history.duration = "32d"
      }

      env {
        ES_JAVA_OPTS = "-Xms512m -Xmx512m -XX:+UnlockDiagnosticVMOptions"
      }
      resources {
        memory = 1000
        network {
          mbits = 1
          port "http" {
            static = 8763
          }
        }
      }
      service {
        name = "hoover-stats"
        port = "http"
        tags = ["snoop-/_stats strip=/_stats"]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/_cluster/health"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }

    ${ promtail_task() }
  }
}
