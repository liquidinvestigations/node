job "hoover" {
  datacenters = ["dc1"]
  type = "service"

  group "es" {
    task "es" {
      driver = "docker"
      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch:6.2.4"
        port_map {
          es = 9200
        }
        labels {
          liquid_task = "hoover-es"
        }
      }
      env {
        cluster.name = "hoover"
        # TODO https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html#_notes_for_production_use_and_defaults
      }
      resources {
        memory = 1536
        network {
          port "es" {}
        }
      }
      service {
        name = "hoover-es"
        port = "es"
      }
    }
  }
}
