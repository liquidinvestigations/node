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

./liquid deploy

echo "Liquid provisioned successfully." > /dev/null
