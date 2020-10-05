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
          image = "${config.image('newsleak')}"
          volumes = [
            "{% raw %}${meta.liquid_volumes}{% endraw %}/newsleak/ui/themes::/etc/settings/"
          ]
          args = ["/bin/sh", "-c", "chown -R 999:999 /etc/settings/ && echo chown done && /entrypoint.sh "]
          port_map {
            http = 80
          }
          labels {
            liquid_task = "newsleak"
          }
        }
        template {
          destination = "local/conf"
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
            nerserviceurl = {{- range service "newsleak-ner" -}}"{{.Address}}:{{.Port}}"{{- end -}}
            dictionaryfiles = fck.all, deu:fck.deu, eng:fck.eng
            patternemail = true
            patternurl = false
            patternphone = false
            patternip = false

            # datareader (csv, hoover, or else)
            datareader = hoover

            # CSV datareader options
            datadirectory = ./data
            documentfile = document.csv
            metadatafile = metadata.csv

            # Hoover datareader options
            hooverindex = testdata
            hooverclustername = elasticsearch
            hooverurl = {{- range service "hoover-es-data" -}}"{{.Address}}"{{- end -}}
            hooversearchurl = {{- range service "newsleak-ner" -}}"{{.Address}}:{{.Port}}"{{- end -}}
            hooverport = {{- range service "hoover-es-data" -}}"{{.Port}}"{{- end -}}
            hoovertmpmetadata = hoover_metadata.csv
            processlanguages = eng, ron, deu
            # Newsleak postgres
            dburl = {{- range service "newsleak-pg" -}}"{{.Address}}:{{.Port}}"{{- end -}}
            dbname = newsleak
            dbuser = newsreader
            dbpass = newsreader
            dbschema = desc/postgresSchema.sql
            dbindices = desc/postgresIndices.sql

            # Newsleak elasticsearch index
            esindex = newsleak
            esurl = {{- range service "newsleak-es-transport" -}}"{{.Address}}"{{- end -}}
            esclustername = elasticsearch
            esport = {{- range service "newsleak-es-transport" -}}"{{.Port}}"{{- end -}}
          EOF
      }
    
    }
  }
}