#!/bin/bash -e

cd "$( dirname "${BASH_SOURCE[0]}" )"

export DASHBOARD_ID='458d5420-3948-11ea-abe8-8739c7922b20'
export KIBANA_URL='http://10.66.60.1:23264'

curl "$KIBANA_URL/api/kibana/dashboards/export?dashboard=$DASHBOARD_ID" > snoop.json
