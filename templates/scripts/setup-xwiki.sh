#!/bin/bash
set -ex


retries=0
max_retries=20

while [ $retries -lt $max_retries ]; do
  if curl -f $XWIKI_URL/rest/; then
    echo "Xwiki is ready. Searching for allocation..."
    echo $NOMAD_URL

    # unfortunatley parsing the json doesn't work since jq is not available instead we split the json objets
    # into seperate lines and grep the running one and get the id from it
    # beginning of the line looks like this: {"ID":"b7ca39fa-a962-5900-41b7-ae14728f6c70",...
    allocationId=$(curl -s $NOMAD_URL/v1/job/xwiki/allocations | sed 's/},{/}\n{/g' | grep '"ClientStatus":"running"' | awk -F'"' '{print $4}')
    if [ -n "$allocationId" ]; then
      echo "Found running allocation: $allocationId"
      break
    else
      echo "No running allocation found. Retrying..."
    fi
  else
    echo "Waiting for Xwiki to be ready..."
  fi
  retries=$((retries + 1))
  sleep 10
done
  

if [ $retries -ge $max_retries ]; then
  echo "Reached maximum retries. Exiting."
  exit 1
fi

echo ""
echo "Xwiki is ready. Running setup..."
echo ""
curl -i --user "superadmin:$PASSWORD" -X PUT -H "Content-Type: text/xml" "$XWIKI_URL/rest/jobs?jobType=install&async=false" --upload-file local/installjobrequest.xml
echo ""
echo "Installing oidc extension done. Restarting service..."
curl -X POST -d '{"TaskName": "xwiki"}' $NOMAD_URL/v1/client/allocation/$allocationId/restart
echo ""
echo "Restarted service."
