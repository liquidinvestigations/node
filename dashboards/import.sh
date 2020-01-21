#!/bin/bash -e

cd "$( dirname "${BASH_SOURCE[0]}" )"

export DASHBOARD_ID='458d5420-3948-11ea-abe8-8739c7922b20'
export KIBANA_URL='http://10.66.60.1:23264'

curl -X POST "$KIBANA_URL/api/kibana/dashboards/import" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' --data-binary @snoop.json
