#!/bin/bash -ex

if [ $EUID -eq 0 ]; then
  chmod 755 $0
  echo "I'm root, switching to vagrant." > /dev/null
  exec sudo -iu vagrant $0
fi

echo "Hello, my name is $(whoami)." > /dev/null

echo "Installing liquid" > /dev/null

cd /opt/node
sudo chown -R vagrant: .

if ! [ -e volumes ]; then
  mkdir -p /opt/var/node/volumes
  ln -s /opt/var/node/volumes
fi

if ! [ -e collections ]; then
  mkdir -p /opt/var/node/collections
  ln -s /opt/var/node/collections
fi

cp /tmp/vagrant-liquid.ini liquid.ini

./liquid deploy

echo "Liquid provisioned successfully." > /dev/null
