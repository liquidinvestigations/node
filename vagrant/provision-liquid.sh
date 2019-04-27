#!/bin/bash -ex

if [ $EUID -eq 0 ]; then
  chmod 755 $0
  echo "I'm root, switching to vagrant."
  exec sudo -iu vagrant $0
fi

echo "Hello, my name is $(whoami)."

echo "Installing liquid"

cd /opt/node
sudo chown -R vagrant: .

cat > liquid.ini <<EOF
[liquid]
domain = liquid.example.com
debug = true

[cluster]
vault_secrets = ../cluster/var/vault-secrets.ini
EOF

./liquid deploy

echo "Liquid provisioned successfully."
