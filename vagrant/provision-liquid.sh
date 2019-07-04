#!/bin/bash -ex

id $(whoami)

echo "Installing liquid" > /dev/null

cd /opt/node
sudo chown -R vagrant: .

if ! [ -e volumes ]; then
  mkdir -p /opt/var/node/volumes
  rm -f volumes
  ln -s /opt/var/node/volumes
fi

if ! [ -e collections ]; then
  mkdir -p /opt/var/node/collections
  rm -f collections
  ln -s /opt/var/node/collections
fi

if ! [ -e collections/testdata ]; then
  git clone https://github.com/hoover/testdata collections/testdata
fi

cp examples/liquid.ini .

./liquid resources
./liquid deploy

echo "Liquid provisioned successfully." > /dev/null
