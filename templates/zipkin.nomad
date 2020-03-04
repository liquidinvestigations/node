{% from '_lib.hcl' import shutdown_delay, group_disk, task_logs -%}

job "zipkin" {
  datacenters = ["dc1"]
  type = "service"
  priority = 25

  group "es" {
    task "es" {
      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      ${ shutdown_delay() }

      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch:7.5.1"
        args = ["/bin/sh", "-c", "chown 1000:1000 /usr/share/elasticsearch/data && echo chown done && /usr/local/bin/docker-entrypoint.sh"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/zipkin/es:/usr/share/elasticsearch/data",
        ]
        port_map {
          http = 9200
        }
        labels {
          liquid_task = "zipkin-es"
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
        discovery.type = "single-node"
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
    }
  }

  group "kibana" {
    task "kibana" {
      driver = "docker"
      config {
        image = "docker.elastic.co/kibana/kibana:7.5.1"
        labels {
          liquid_task = "zipkin-kibana"
        }
        port_map {
          http = 5601
        }
      }
      env {
        ELASTICSEARCH_HOSTS = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:8763"
      }
      resources {
        memory = 2000
        cpu = 200
        network {
          mbits = 1
          port "http" {
            static = 23264
          }
        }
      }
      service {
        name = "zipkin-kibana"
        port = "http"
        check {
          name = "zipkin-kibana"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
    }
  }

  group "zipkin" {
    ${ group_disk() }

    task "zipkin" {
      ${ task_logs() }

      driver = "docker"
      ${ shutdown_delay() }
      config {
        image = "openzipkin/zipkin"
        labels {
          liquid_task = "zipkin"
        }
        port_map {
          http = 9411
        }
      }
      env {
        STORAGE_TYPE = "elasticsearch"
        ES_HOSTS = "{% raw %}${attr.unique.network.ip-address}{% endraw %}:8763"
      }
      resources {
        memory = 8000
        cpu = 200
        network {
          mbits = 1
          port "http" {
            static = 23263
          }
        }
      }
      service {
        name = "zipkin"
        port = "http"
        check {
          name = "zipkin"
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
