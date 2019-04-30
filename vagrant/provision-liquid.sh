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

cp vagrant/ci-liquid.ini liquid.ini

./liquid deploy

echo "Liquid provisioned successfully."
