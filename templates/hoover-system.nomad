job "hoover-system" {
  datacenters = ["dc1"]
  type = "system"
  priority = 77

  group "collections-lb" {
    task "fabio" {
      driver = "docker"
      config {
        image = "fabiolb/fabio:1.5.11-go1.11.5"
        volumes = [
          "local/fabio.properties:/etc/fabio/fabio.properties"
        ]
        port_map {
          ui = 9991
          lb = 9990
        }
      }
      template {
        destination = "local/fabio.properties"
        data = <<-EOH
          registry.backend = consul
          registry.consul.addr = ${consul_url}
          registry.consul.checksRequired = all
          registry.consul.tagprefix = snoop-
          registry.consul.kvpath = /liquid/hoover/fabio
          registry.consul.register.enabled = false
          ui.addr = :9991
          ui.color = blue
          proxy.addr = :9990
          EOH
      }

      resources {
        cpu = 100
        memory = 100
        network {
          mbits = 1
          port "lb" {
            static = 8765
          }
          port "ui" {
            static = 8764
          }
        }
      }
    }
  }
}
