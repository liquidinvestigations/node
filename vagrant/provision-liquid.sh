#!/bin/bash -e

if [ $EUID -eq 0 ]; then
  echo "I'm root, switching to vagrant."
  exec sudo -iu vagrant bash $0
fi

echo "Hello, my name is $(whoami)."

echo "Installing liquid"

git clone https://github.com/liquidinvestigations/node /opt/node
cd /opt/node

cat > liquid.ini <<EOF
[liquid]
domain = liquid.example.com
debug = true

[cluster]
vault_secrets = ../cluster/var/vault-secrets.ini
EOF

./liquid deploy

echo "Liquid provisioned successfully."
