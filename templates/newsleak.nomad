{% from '_lib.hcl' import shutdown_delay, authproxy_group, continuous_reschedule, set_pg_password_template, task_logs, group_disk with context -%}

job "newsleak" {
  datacenters = ["dc1"]
  type = "service"
  priority = 60

  group "newsleak" {
    ${ group_disk() }
    task "newsleak-ui" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "${config.image('liquid-newsleak')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/newsleak/ui/:/etc/settings/"
        ]
        # args = ["/bin/sh", "-c", " cp /local/conf /etc/settings/conf/newsleak.properties && chown 999:999 /etc/settings/conf/newsleak.properties &&echo conf loaded && /opt/newsleak/newsleak-start.sh" ]
        port_map {
          ui = 9000
        }
        labels {
          liquid_task = "newsleak"
        }
      }
      service {
        name = "newsleak-ui"
        port = "ui"
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
        }
      }
      resources {
        memory = 7000
        network {
          mbits = 1
          port "ui" {}
        }
      }
      template {
          destination = "/local/conf"
          perms = "755"
          data = <<-EOF
            ################################
            ##     NEWSLEAK CONFIG        ##
            ################################

            # processing configuration
            processlanguages = eng, deu
            defaultlanguage = eng
            paragraphsasdocuments = false
            paragraphminimumlength = 1500
            maxdocumentlength = 500000
            debugMaxDocuments = 0
            threads = 4

            # ner, dictionaries and pattern extraction
            nerserviceurl = http://{{- range service "newsleak-ner" -}}{{.Address}}:{{.Port}}{{- end }}
            dictionaryfiles = fck.all, deu:fck.deu, eng:fck.eng
            patternemail = true
            patternurl = false
            patternphone = false
            patternip = false

            # datareader (csv, hoover, or else)
            datareader = hoover

            # CSV datareader options
            datadirectory = /opt/newsleak/data
            documentfile = document.csv
            metadatafile = metadata.csv

            # Hoover datareader options
            hooverindex = ww2
            hooverclustername = hoover
            hooverurl = http://{{- range service "hoover-es-master" -}}{{.Address}}{{- end }}
            hooversearchurl = http://hoover.${config.liquid_domain}:{{- range service "hoover-search" -}}{{.Port}}{{- end }}
            hooverport = {{- range service "hoover-es-master" -}}{{.Port}}{{- end }}
            hoovertmpmetadata = hoover_metadata.csv
            processlanguages = eng, ron, deu
            # Newsleak postgres
            dburl = {{- range service "newsleak-pg" -}}{{.Address}}:{{.Port}}{{- end }}
            dbname = newsleak
            dbuser = newsreader
            dbpass = newsreader
            dbschema = /opt/newsleak/desc/postgresSchema.sql
            dbindices = /opt/newsleak/desc/postgresIndices.sql

            # Newsleak elasticsearch index
            esindex = newsleak
            esurl = {{- range service "newsleak-es-transport" -}}{{.Address}}{{- end }}
            esclustername = elasticsearch
            esport = {{- range service "newsleak-es-transport" -}}{{.Port}}{{- end }}
          EOF
      }
      template {
        destination = "/local/application.production.conf"
        perms = "755"
        data = <<-EOF
          # This is the main configuration file for the application.
          # ~~~~~

          # Production mode settings
          # ~~~~~
          application.mode=PROD

          # XForwardedSupport="127.0.0.1"

          # play.http.context="/noden/"
          # play.http.context="/newsleak/"

          # Secret key
          # ~~~~~
          # The secret key is used to secure cryptographics functions.
          # If you deploy your application to several instances be sure to use the same key!
          play.crypto.secret="CHANGE-THIS-APPLICATION-SECRET-PLEASE_48njXsy34tDJHusy2J"

          # The application languages
          # ~~~~~
          play.i18n.langs= ["en"]

          # Global object class
          # ~~~~~
          # Define the Global object class for this application.
          # Default to Global in the root package.
          # application.global=Global

          # Router
          # ~~~~~
          # Define the Router object to use for this application.
          # This router will be looked up first when the application is starting up,
          # so make sure this is the entry point.
          # Furthermore, it's assumed your route file is named properly.
          # So for an application router like `my.application.Router`,
          # you may need to define a router file `conf/my.application.routes`.
          # Default to Routes in the root package (and conf/routes)
          # application.router=my.application.Routes


          # Authorization
          # ~~~~~
          #
          authorization.enabled=false
          authorization.login="user"
          authorization.password="test"


          # Data Source Configuration
          # ~~~~~
          # You can declare as many datasources as you want.
          # By convention, the default datasource is named `default`
          #

          # base url for UI links to original sources (e.g. Hoover)
          source.base.url = "http://hoover.${config.liquid_domain}:{{- range service "hoover-search" -}}{{.Port}}{{- end }}/doc/"

          # Available ES collections (provide db.* configuration for each collection below)
          es.indices =  [newsleak,newsleak2,newsleak3,newsleak4,newsleak5]
          # ES connection
          es.clustername = "elasticsearch"
          es.address = "{{- range service "newsleak-es-transport" -}}{{.Address}}{{- end }}"
          es.port = {{- range service "newsleak-es-transport" -}}{{.Port}}{{- end }}

          # Determine the default dataset for the application
          es.index.default = "newsleak"

          # collection 1
          db.newsleak.driver=org.postgresql.Driver
          db.newsleak.url="jdbc:postgresql://{{- range service "newsleak-pg" -}}{{.Address}}:{{.Port}}{{- end }}/newsleak"
          db.newsleak.username="newsreader"
          db.newsleak.password="newsreader"
          es.newsleak.excludeTypes = [Link,Filename,Path,Content-type,SUBJECT,HEADER,Subject,Timezone,sender.id,Recipients.id,Recipients.order]

          # collection 2
          db.newsleak2.driver=org.postgresql.Driver
          db.newsleak2.url="jdbc:postgresql://{{- range service "newsleak-pg" -}}{{.Address}}:{{.Port}}{{- end }}/newsleak2"
          db.newsleak2.username="newsreader"
          db.newsleak2.password="newsreader"
          es.newsleak2.excludeTypes = [Link,Filename,Path,Content-type,SUBJECT,HEADER,Subject,Timezone,sender.id,Recipients.id,Recipients.order]

          # collection 3
          db.newsleak3.driver=org.postgresql.Driver
          db.newsleak3.url="jdbc:postgresql://{{- range service "newsleak-pg" -}}{{.Address}}:{{.Port}}{{- end }}/newsleak3"
          db.newsleak3.username="newsreader"
          db.newsleak3.password="newsreader"
          es.newsleak3.excludeTypes = [Link,Filename,Path,Content-type,SUBJECT,HEADER,Subject,Timezone,sender.id,Recipients.id,Recipients.order]

          # collection 4
          db.newsleak4.driver=org.postgresql.Driver
          db.newsleak4.url="jdbc:postgresql://{{- range service "newsleak-pg" -}}{{.Address}}:{{.Port}}{{- end }}/newsleak4"
          db.newsleak4.username="newsreader"
          db.newsleak4.password="newsreader"
          es.newsleak4.excludeTypes = [Link,Filename,Path,Content-type,SUBJECT,HEADER,Subject,Timezone,sender.id,Recipients.id,Recipients.order]

          # collection 5
          db.newsleak5.driver=org.postgresql.Driver
          db.newsleak5.url="jdbc:postgresql://{{- range service "newsleak-pg" -}}{{.Address}}:{{.Port}}{{- end }}/newsleak5"
          db.newsleak5.username="newsreader"
          db.newsleak5.password="newsreader"
          es.newsleak5.excludeTypes = [Link,Filename,Path,Content-type,SUBJECT,HEADER,Subject,Timezone,sender.id,Recipients.id,Recipients.order]

          # --------------------
          # Other configurations
          scalikejdbc.global.loggingSQLAndTime.enabled=false
          scalikejdbc.global.loggingSQLAndTime.singleLineMode=false
          scalikejdbc.global.loggingSQLAndTime.logLevel=info
          scalikejdbc.global.loggingSQLAndTime.warningEnabled=false
          scalikejdbc.global.loggingSQLAndTime.warningThresholdMillis=5
          scalikejdbc.global.loggingSQLAndTime.warningLogLevel=warn

          play.modules.enabled += "scalikejdbc.PlayModule"
          # scalikejdbc.PlayModule doesn't depend on Play's DBModule
          play.modules.disabled += "play.api.db.DBModule"
        EOF
      }
    }
  }
}

