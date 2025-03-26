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
echo "Installing OIDC extension..."
curl --user "superadmin:$PASSWORD" -X PUT -H "Content-Type: text/xml" "$XWIKI_URL/rest/jobs?jobType=install&async=false" --upload-file local/install-oidc.xml
echo ""

echo "Installing custom CSS..."
curl --user "superadmin:$PASSWORD" -X PUT -H "Content-Type: text/xml" "$XWIKI_URL/rest/wikis/xwiki/spaces/Main/pages/customcss" --data-binary "@local/emptypage.xml"

echo "Check if style sheet extension exists..."
if curl --user "superadmin:$PASSWORD" -X GET "$XWIKI_URL/rest/wikis/xwiki/spaces/Main/pages/customcss/objects" | grep "StyleSheetExtension"; then
  echo "StyleSheetExtension already exists. Skipping installation."
else
  echo "Installing style sheet extension..."
  curl --user "superadmin:$PASSWORD" -X POST -H "Content-Type: text/xml" "$XWIKI_URL/rest/wikis/xwiki/spaces/Main/pages/customcss/objects" --data-binary "@local/installcss.xml"
fi

echo "Installing oidc extension and custom CSS done. Restarting service..."
curl -X POST -d '{"TaskName": "xwiki"}' $NOMAD_URL/v1/client/allocation/$allocationId/restart
echo ""
echo "Restarted service."
