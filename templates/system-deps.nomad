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
        image = "fabiolb/fabio:1.6.0"
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
        memory = 256
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
        image = "telegraf:1.22-alpine"
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

  group "vector" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay = "20s"
      mode = "delay"
    }
    ephemeral_disk {
      size    = 300
      sticky  = true
    }
    task "vector" {
      driver = "docker"
      config {
        hostname = "{% raw %}${node.unique.name}{% endraw %}"
        # image = "timberio/vector:0.14.X-alpine"
        image = "timberio/vector:0.27.X-alpine"
        port_map {
          api = 8686
        }
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro"
        ]
      }
      # Vector won't start unless the sinks(backends) configured are healthy
      env {
        VECTOR_CONFIG = "local/vector.toml"
        VECTOR_REQUIRE_HEALTHY = "true"
      }
      # resource limits are a good idea because you don't want your log collection to consume all resources available
      resources {
        cpu    = 500 # 500 MHz
        memory = 256 # 256MB
        network {
          port "api" { }
        }
      }
      # template with Vector's configuration
      template {
        destination = "local/vector.toml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        # overriding the delimiters to [[ ]] to avoid conflicts with Vector's native templating, which also uses {{ }}
        left_delimiter = "[["
        right_delimiter = "]]"
        data=<<EOH
          data_dir = "alloc/data/vector/"
          [api]
            enabled = true
            address = "0.0.0.0:8686"
            playground = true
          [sources.docker_logs_raw]
            type = "docker_logs"

          # [sources.syslog]
          #   type = "syslog"

          # [sources.journald]
          #   type = "journald"
          #   current_boot_only = true

          [transforms.docker_logs_guess_severity_lua]
          type = "lua"
          inputs = ["docker_logs_raw"]
          version = "2"
          hooks.process = """
function (event, emit)
  if event.log.label.nomad_job then
    event.log.nomad_job = event.log.label.nomad_job
    event.log.nomad_group = event.log.label.nomad_group
    event.log.nomad_task = event.log.label.nomad_task
  end
  emit(event)
end
"""

          [transforms.try_parse_more]
          type = "remap"
          inputs = ["docker_logs_guess_severity_lua"]
          source = """
oldhost = .host
structured =
  parse_syslog(.message) ??
  parse_common_log(.message) ??
  # parse_logfmt(.message) ??
  parse_klog(.message) ??
  # parse_nginx_log(.message, "combined") ??
  parse_nginx_log(.message, "error") ??
  # parse_apache_log(.message, "common") ??
  # parse_apache_log(.message, "combined") ??
  parse_apache_log(.message, "error") ??
  parse_regex!(.message, r'^(?P<message>.*)$')
. = merge(., structured)
.host = oldhost
"""

          [transforms.try_parse_severity]
          type = "remap"
          inputs = ["try_parse_more"]
          source = """

  if contains(string!(.message), "warn", case_sensitive: false) {
    .severity = "warn"
  }

  if contains(string!(.message), "error", case_sensitive: false) {
    .severity = "error"
  }

  if contains(string!(.message), "fatal", case_sensitive: false) || contains(string!(.message), "panic", case_sensitive: false){
    .severity = "fatal"
  }


  if contains(string!(.message), "debug", case_sensitive: false) || contains(string!(.message), "detail", case_sensitive: false) {
    .severity = "debug"
  }

if is_string(.message) {
  if contains(string!(.message), "trace", case_sensitive: false) || contains(string!(.message), "uptrace", case_sensitive: false) {
    .severity = "trace"
  }

}
"""

          [transforms.filter_out_clickhouse]
          type = "filter"
          inputs = ["try_parse_severity"]
          condition = '.nomad_group != "monitoring.clickhouse"'


          [sinks.clickhouse]
            type = "http"
            inputs = ["filter_out_clickhouse"] #, "syslog", "journald"]
            # uri = "http://10.49.0.2:6666/api/v1/vector/logs"

            uri = "http://[[ env "attr.unique.network.ip-address" ]]:${config.port_lb}/uptrace/api/v1/vector/logs"
            request.headers.uptrace-dsn = "http://liquid-docker-logs@localhost:14317/2"

            encoding.codec = "json"
            framing.method = "newline_delimited"
            compression = "gzip"

            healthcheck.enabled = true
            # since . is used by Vector to denote a parent-child relationship, and Nomad's Docker labels contain ".",
            # we need to escape them twice, once for TOML, once for Vector
            # labels.job = "{{ label.com\\.hashicorp\\.nomad\\.job_name }}"
            # labels.task = "{{ label.com\\.hashicorp\\.nomad\\.task_name }}"
            # labels.group = "{{ label.com\\.hashicorp\\.nomad\\.task_group_name }}"
            # labels.namespace = "{{ label.com\\.hashicorp\\.nomad\\.namespace }}"
            # labels.node = "{{ label.com\\.hashicorp\\.nomad\\.node_name }}"
            # # remove fields that have been converted to labels to avoid having the field twice
            # remove_label_fields = true
        EOH
      }
      service {
        name = "vector-http"
        port     = "api"
        check {
          name = "http"
          type     = "http"
          path     = "/health"
          interval = "35s"
          timeout  = "25s"
        }
      }
      kill_timeout = "30s"
    }
  }
}
