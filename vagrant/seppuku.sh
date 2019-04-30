#!/bin/bash -e

echo "Getting droplet ID ..."
droplet_address="$(ip route get 8.8.8.8 | awk '{ print $7; exit }')"
droplet_id="$(
curl \
  -H "Authorization: Bearer $DO_TOKEN" \
  "https://api.digitalocean.com/v2/droplets" \
  | jq ".droplets[] | select(contains({networks: {v4: [{ip_address: \"$droplet_address\"}]}}))" \
  | jq '.id'
)"
echo "Droplet ID is $droplet_id"

echo "Sleeping $DO_SEPPUKU seconds from $(date) ..."
sleep $DO_SEPPUKU

echo "Woke up, killing self"
curl \
  -XDELETE \
  -H "Authorization: Bearer $DO_TOKEN" \
  "https://api.digitalocean.com/v2/droplets/$droplet_id"
