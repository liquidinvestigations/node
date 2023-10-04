job "system-deps" {
  datacenters = ["dc1"]
  type = "system"
  priority = 99

  # group "dnsmasq" {
  #   restart {
  #     attempts = 10
  #     interval = "5m"
  #     delay = "10s"
  #     mode = "delay"
  #   }

  #   task "dnsmasq" {
  #     driver = "docker"
  #     config {
  #       image = "andyshinn/dnsmasq:2.83"
  #       port_map {
  #         dns = 53
  #       }
  #       args = ["--log-facility=-", "--conf-file=/etc/dnsmasq.conf"]
  #       cap_add = ["NET_ADMIN"]
  #       volumes = [
  #         "local/dnsmasq.conf:/etc/dnsmasq.conf"
  #       ]
  #     }

  #     template {
  #       data = <<-EOF
  #       bind-interfaces
  #       #no-resolv
  #       #no-poll
  #       #no-hosts
  #       #log-dhcp
  #       #log-queries
  #       server=/consul/{{env "attr.unique.network.ip-address"}}#8600
  #       #server=1.2.3.4
  #       #server=208.67.222.222
  #       #server=8.8.8.8
  #       EOF

  #       destination = "local/dnsmasq.conf"
  #     }

  #     resources {
  #       cpu    = 50
  #       memory = 50
  #       network {
  #         mbits = 10
  #         port "dns" {
  #           static = 53
  #         }
  #       }
  #     }

  #     service {
  #       name = "dnsmasq"
  #       port = "dns"
  #     }
  #   }
  # }

  group "fabio" {
    restart {
      attempts = 10
      delay    = "20s"
      interval = "5m"
      mode     = "delay"
    }

    # Error submitting job: Unexpected response code: 500 (1 error occurred:
    # 	* Task group fabio validation failed: 1 error occurred:
    # 	* System jobs should not have a reschedule policy
    #
    # reschedule {
    #   attempts       = 0
    #   delay          = "15s"
    #   delay_function = "exponential"
    #   max_delay      = "10m"
    #   unlimited      = true
    # }

    task "fabio" {
      driver = "docker"
      config {
        image = "${config.image('fabio')}"
        volumes = [
          "local/fabio.properties:/etc/fabio/fabio.properties"
        ]
        port_map {
          ui = 8000
          ${config.port_map()}
        }
        memory_hard_limit = 3000
        labels {
          liquid_task = "fabio"
        }
      }
      template {
        destination = "local/fabio.properties"
        data = <<-EOH
        registry.backend = consul
        registry.consul.addr = {{env "attr.unique.network.ip-address"}}:8500
        registry.consul.checksRequired = all
        registry.consul.tagprefix = fabio-
        registry.consul.kvpath = /cluster/fabio
        registry.consul.register.enabled = false

        ui.addr = :8000
        ui.color = green
        proxy.addr = ${config.ports_proxy_addr()}
        EOH
      }

      resources {
        cpu    = 200
        memory = 64
        network {
          mbits = 10
          ${config.ports_resources_network()}
          port "ui" {}
        }
      }

      service {
        name = "cluster-fabio"
        port = "lb"
        check {
          name     = "tcp"
          type     = "tcp"
          interval = "35s"
          timeout  = "32s"
        }
      }

      service {
        name = "cluster-fabio-ui"
        port = "ui"
        check {
          name     = "http"
          type     = "http"
          path     = "/"
          interval = "35s"
          timeout  = "33s"
        }
      }
    }
  }

  {% if config.apps_monitoring_enabled %}
  group "telegraf" {
    restart {
      attempts = 5
      interval = "5m"
      delay = "30s"
      mode = "delay"
    }
    task "telegraf" {
      driver = "docker"
      # root for reading docker.sock
      user = "root"
      config {
        image = "${config.image('telegraf')}"
        dns_servers = ["{% raw %}${attr.unique.network.ip-address}{% endraw %}"]
        port_map {
          statsd = 8125
          http = 8123
          port = 8124
        }
        args = ["--config", "/local/telegraf.conf"]

        volumes = ["/var/run/docker.sock:/var/run/docker.sock:ro"]
        network_mode = "host"
        privileged = true
        memory_hard_limit = 500
      }

      template {
        destination = "local/telegraf.conf"
        data = <<-EOF
          [agent]
            interval = "30s"
            flush_interval = "30s"
            omit_hostname = false
            debug = false
            quiet = false

          [[inputs.sensors]]
          [[inputs.docker]]
          [[inputs.cpu]]
            percpu = true
            totalcpu = true
            collect_cpu_time = false
          [[inputs.disk]]
          [[inputs.diskio]]
          [[inputs.kernel]]
          [[inputs.linux_sysctl_fs]]
          [[inputs.mem]]
          [[inputs.net]]
            interfaces = ["*"]
          [[inputs.netstat]]
          [[inputs.processes]]
          [[inputs.swap]]
          [[inputs.system]]
          [[inputs.procstat]]
            pattern = "(consul|vault)"

          [[inputs.statsd]]
            protocol = "udp"
            service_address = "{{env "attr.unique.network.ip-address"}}:8125"
            delete_gauges = true
            delete_counters = true
            delete_sets = true
            delete_timings = true
            percentiles = [90]
            metric_separator = "_"
            parse_data_dog_tags = true
            allowed_pending_messages = 10000
            percentile_limit = 1000

          [[inputs.consul]]
            address = "http://{{env "attr.unique.network.ip-address"}}:8500"
            scheme = "http"

          [[inputs.prometheus]]
            urls = ["http://{{env "attr.unique.network.ip-address"}}:4646/v1/metrics?format=prometheus"]

          # TODO collect vault metrics: Need Client Token set as header X-Vault-Token
          #[[inputs.prometheus]]
          #  urls = ["http://{{env "attr.unique.network.ip-address"}}:8200/v1/sys/metrics?format=prometheus"]
          # Configuration for the Prometheus client to spawn
          [[outputs.prometheus_client]]
            ## Address to listen on.
            listen = ":8124"

          [[outputs.health]]
            service_address = "http://{{env "attr.unique.network.ip-address"}}:8123"
          EOF
      }

      resources {
        cpu    = 100
        memory = 150
        network {
          mbits = 1
          port "udp" { static = 8125 }
          port "http" { static = 8123 }
          port "prom_client" { static = 8124 }
        }
      }

      service {
        name = "telegraf-prom-client"
        port = "prom_client"
        check {
          name     = "tcp"
          type     = "tcp"
          interval = "38s"
          timeout  = "34s"
        }
      }
      service {
        name = "telegraf"
        port = "http"
        check {
          name     = "http"
          type     = "http"
          path     = "/"
          interval = "39s"
          timeout  = "36s"
        }
      }
    }
  }
  {% endif %}

}
