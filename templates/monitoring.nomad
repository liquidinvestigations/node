job "monitoring" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  group "prometheus" {
    constraint {
      attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
      operator = "is_set"
    }

    reschedule {
      unlimited = true
      attempts = 0
      delay = "40s"
    }

    restart {
      attempts = 4
      interval = "48s"
      delay = "10s"
      mode = "fail"
    }

    ephemeral_disk {
      size = 300
      sticky = true
    }

    task "prometheus" {
      template {
        data = <<EOF
{% include 'prometheus_rules.yml' %}
        EOF
        destination = "local/prometheus_rules.yml"
      }

      template {
        data = <<EOF
{% include 'prometheus.yml' %}
        EOF
        destination = "local/prometheus.yml"
      }
      driver = "docker"
      user = "root"
      config {
        image = "prom/prometheus:v2.36.0"
        args = [
          "--web.route-prefix=/prometheus",
          "--web.external-url=http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/prometheus",
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.retention.time=15d",
         ]
        volumes = [
          "local/prometheus_rules.yml:/etc/prometheus/prometheus_rules.yml:ro",
          "local/prometheus.yml:/etc/prometheus/prometheus.yml:ro",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/prometheus/2.19.2:/prometheus",
        ]
        port_map {
          http = 9090
        }
        memory_hard_limit = 2000
      }
      resources {
        memory = 400
        network {
          mbits = 10
          port "http" {
          }
        }
      }
      service {
        name = "prometheus"
        port = "http"
        tags = ["fabio-/prometheus"]
        check {
          name     = "Prometheus alive on HTTP"
          type     = "http"
          path     = "/prometheus/-/healthy"
          interval = "34s"
          timeout  = "32s"
        }
      }
    }
  }

  group "grafana" {
    restart {
      attempts = 3
      interval = "2m"
      delay = "30s"
      mode = "delay"
    }

    task "grafana" {
      driver = "docker"
      config {
        image = "grafana/grafana:7.5.16"
        dns_servers = ["{% raw %}${attr.unique.network.ip-address}{% endraw %}"]
        port_map {
          http = 3000
        }
        memory_hard_limit = 3000
      }

      env {
        GF_PATHS_PROVISIONING = "/local/provisioning"

        GF_SECURITY_DISABLE_GRAVATAR = "true"

        GF_SERVER_ROOT_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:9990/grafana"
        GF_SERVER_SERVE_FROM_SUB_PATH = "true"
        GF_SERVER_ENABLE_GZIP = "true"

        GF_AUTH_BASIC_ENABLED = "false"
        GF_AUTH_ANONYMOUS_ENABLED = "true"
        GF_AUTH_ANONYMOUS_ORG_NAME = "Main Org."
        GF_AUTH_ANONYMOUS_ORG_ROLE = "Admin"

        GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH = "/local/dashboards/system-metrics-telegraf-prom.json"
        GF_DASHBOARDS_MIN_REFRESH_INTERVAL = "30s"
      }

      template {
        destination = "/local/provisioning/dashboards/cluster.yaml"
        data = <<-EOF
          apiVersion: 1
          providers:
          - name: 'cluster'
            orgId: 1
            folder: ''
            type: file
            disableDeletion: false
            editable: true
            updateIntervalSeconds: 30
            options:
              path: /local/dashboards
          EOF
      }

      template {
        destination = "/local/provisioning/datasources/cluster.yaml"
        data = <<-EOF
          apiVersion: 1
          datasources:
          - {
            "access": "proxy",
            "basicAuth": false,
            "isDefault": false,
            "jsonData": {
                "httpMethod": "GET",
                "keepCookies": []
            },
            "name": "Prometheus",
            "readOnly": false,
            "type": "prometheus",
            "url": "http://{{env "attr.unique.network.ip-address"}}:9990/prometheus",
            "version": 2,
            "withCredentials": false
          }
          - {
            "access": "proxy",
            "basicAuth": false,
            "isDefault": false,
            "jsonData": {
                "interval": "Daily",
                "timeField": "timestamp",
                "esVersion": "60",
            },
            "name": "Hoover Elasticsearch Metrics",
            "readOnly": false,
            "type": "elasticsearch",
            "database": "[.monitoring-es-6-]YYYY.MM.DD",
            "url": "http://{{env "attr.unique.network.ip-address"}}:9990/_es",
            "version": 2,
            "withCredentials": false
          }
          EOF
      }

      {% for filename in config.get_dashboards() %}
      template {
        destination = "/local/dashboards/${ filename }"
        left_delimiter = "I_HOPE_THIS"
        right_delimiter = "WONT_SHOW_UP"
        data = <<-EOF
          ${ config.load_dashboard(filename) }
          EOF
      }
      {% endfor %}

      resources {
        cpu    = 200
        memory = 400
        network {
          mbits = 10
          port "http" {}
        }
      }

      service {
        name = "grafana"
        port = "http"
        tags = ["fabio-/grafana"]
        check {
          name     = "Grafana alive on HTTP"
          type     = "http"
          path     = "/grafana/api/health"
          interval = "34s"
          timeout  = "32s"
        }
      }
    }
  }
}
