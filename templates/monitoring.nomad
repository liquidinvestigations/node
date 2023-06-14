job "monitoring" {
  datacenters = ["dc1"]
  type = "service"
  priority = 99

  group "clickhouse" {
    constraint {
      attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
      operator = "is_set"
    }

    reschedule {
      unlimited = true
      attempts = 0
      delay = "60s"
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

    task "clickhouse" {
      driver = "docker"
      user = "root"
      config {
        ulimit {
          memlock = "-1"
          nofile = "262144"
          nproc = "8192"
        }
        image = "bitnami/clickhouse:22.12.3"
        entrypoint = ["/bin/bash", "-ex"]
        args = ["/local/startup.sh"]
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/clickhouse/22.12:/bitnami/clickhouse",
          "local/config.xml:/bitnami/clickhouse/conf/conf.d/override.xml",
          "local/users.xml:/bitnami/clickhouse/conf/users.d/override.xml",
        ]
        port_map {
          http = 8123
          clickhouse = 9000
        }
        memory_hard_limit = 5000
      }
      resources {
        memory = 400
        network {
          mbits = 10
          port "http" {}
          port "clickhouse" {}
        }
      }

      template {
        data = <<-EOF
          #!/bin/bash
          set -ex
          echo "hello from clickhouse"
          mkdir -p /bitnami/clickhouse/data
          chown -R clickhouse:clickhouse /bitnami/clickhouse
          /opt/bitnami/scripts/clickhouse/entrypoint.sh /opt/bitnami/scripts/clickhouse/run.sh -- --listen_host=0.0.0.0

          EOF
        env = false
        destination = "local/startup.sh"
      }

      env {
        CLICKHOUSE_DB = "uptrace"
        ALLOW_EMPTY_PASSWORD = "yes"
      }

      # https://clickhouse.uptrace.dev/clickhouse/low-memory.html#configuring-clickhouse
      template {
        data = <<EOF
<?xml version="1.0" ?>
<clickhouse>
  <timezone>UTC</timezone>

  <core_dump>
    <size_limit>0</size_limit>
  </core_dump>

  <compression incl="clickhouse_compression">
    <case>
      <min_part_size>104857600</min_part_size>
      <min_part_size_ratio>0.01</min_part_size_ratio>
      <method>zstd</method>
      <level>3</level>
    </case>
  </compression>

  <logger>
    <level>error</level>
    <console>1</console>
</logger>

  <merge_tree>
    <merge_max_block_size>1024</merge_max_block_size>
    <max_bytes_to_merge_at_max_space_in_pool>1073741824</max_bytes_to_merge_at_max_space_in_pool>
    <number_of_free_entries_in_pool_to_lower_max_size_of_merge>0</number_of_free_entries_in_pool_to_lower_max_size_of_merge>
  </merge_tree>

 <max_concurrent_queries>4</max_concurrent_queries>
 <mark_cache_size>1073741824</mark_cache_size>
 <max_server_memory_usage>4294967296</max_server_memory_usage>

</clickhouse>
        EOF
        destination = "local/config.xml"
      }

      template {
        data = <<EOF
<?xml version="1.0" ?>
<clickhouse>
<profiles>
  <default>
    <prefer_column_name_to_alias>1</prefer_column_name_to_alias>
    <queue_max_wait_ms>9000</queue_max_wait_ms>
    <max_execution_time>20</max_execution_time>
    <background_pool_size>4</background_pool_size>
  </default>
</profiles>
</clickhouse>
        EOF
        destination = "local/users.xml"
      }

      service {
        name = "clickhouse-native"
        port = "clickhouse"
        tags = ["fabio-:${config.port_clickhouse_native} proto=tcp"]
        check {
          name     = "clickhouse native tcp"
          type     = "tcp"
          interval = "35s"
          timeout  = "33s"
        }
      }

      service {
        name = "clickhouse-http"
        port = "http"
        tags = ["fabio-:${config.port_clickhouse_http} proto=tcp", "fabio-/clickhouse strip=/clickhouse"]
        check {
          name     = "clickhouse http"
          type     = "http"
          path     = "/ping"
          interval = "34s"
          timeout  = "32s"
        }
      }
    }
  }

  group "uptrace" {
    constraint {
      attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
      operator = "is_set"
    }

    reschedule {
      unlimited = true
      attempts = 0
      delay = "60s"
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

    task "uptrace" {
      driver = "docker"
      # user = "root"
      config {
        image = "liquidinvestigations/uptrace:1.3.0-liquid"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/uptrace/1.3.0:/var/lib/uptrace",
          "local/uptrace.yml:/etc/uptrace/uptrace.yml:ro",
        ]
        port_map {
          http = 14318
          uptrace = 14317
        }
        memory_hard_limit = 5000
        entrypoint = ["/bin/bash", "-ex"]
        args = ["/local/startup.sh"]
      }
      resources {
        memory = 400
        network {
          mbits = 10
          port "http" {}
          port "uptrace" {}
        }
      }

      template {
        left_delimiter = "[[["
        right_delimiter = "]]]"
        data = <<EOF
{% include 'uptrace-config.yml' %}
        EOF
        destination = "local/uptrace.yml"
      }

      template {
        data = <<-EOF
          #!/bin/bash
          set -ex
          echo "hello from uptrace init script"
          (
           sleep 10
           until ls /var/lib/uptrace/uptrace.sqlite3; do sleep 1; echo "waiting for db"; done
           echo "found db..."
           sleep 10
           echo "inserting dashboards"
           cat /local/dashboards.sql | sqlite3 /var/lib/uptrace/uptrace.sqlite3
           echo "dashboard insertion complete"
          ) &
          exec /entrypoint.sh
          EOF
        env = false
        destination = "local/startup.sh"
      }

      template {
        left_delimiter = "[[["
        right_delimiter = "]]]"
        data = <<-EOF
          ${config.load_uptrace_dashboard('dashboards.sql')}
          EOF
        env = false
        destination = "local/dashboards.sql"
      }

      service {
        name = "uptrace-native"
        port = "uptrace"
        tags = ["fabio-:${config.port_uptrace_native} proto=tcp"]
        check {
          name     = "uptrace native tcp"
          type     = "tcp"
          interval = "35s"
          timeout  = "33s"
        }
      }

      service {
        name = "uptrace-http"
        port = "http"
        tags = ["fabio-:${config.port_uptrace_http} proto=tcp", "fabio-/uptrace strip=/uptrace"]
        check {
          name     = "uptrace http"
          type     = "http"
          path     = "/ping"
          interval = "34s"
          timeout  = "32s"
        }
      }
    }
  }


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
          "--web.external-url=http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/prometheus",
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

        GF_SERVER_ROOT_URL = "http://{% raw %}${attr.unique.network.ip-address}{% endraw %}:${config.port_lb}/grafana"
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
            "url": "http://{{env "attr.unique.network.ip-address"}}:${config.port_lb}/prometheus",
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
            "url": "http://{{env "attr.unique.network.ip-address"}}:${config.port_lb}/_es",
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
