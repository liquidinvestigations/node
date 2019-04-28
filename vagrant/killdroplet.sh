#!/bin/bash -e

sleep_time=900

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

echo "Sleeping $sleep_time seconds"
sleep $sleep_time # 15 minutes

echo "Woke up, killing self"
curl \
  -XDELETE \
  -H "Authorization: Bearer $DO_TOKEN" \
  "https://api.digitalocean.com/v2/droplets/$droplet_id"
