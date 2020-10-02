{% from '_lib.hcl' import shutdown_delay, authproxy_group, continuous_reschedule, set_pg_password_template, task_logs, group_disk with context -%} 

job "newsleak" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  
  group "newsleak" {
    task "nextcloud" {
      ${ group_disk() }

        constraint {
          attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
          operator = "is_set"
        }
        constraint {
          attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
          operator = "is_set"
        }

        driver = "docker"
        config {
          image = "${config.image('newsleak')}"
          volumes = [
            "{% raw %}${meta.liquid_volumes}{% endraw %}/newsleak/ui/themes::/etc/settings/",
          ]
          args = ["/bin/sh", "-c", "chown -R 33:33 /var/www/html/ && echo chown done && /entrypoint.sh apache2-foreground"]
          port_map {
            http = 80
          }
          labels {
            liquid_task = "nextcloud"
          }