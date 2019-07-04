#!/bin/bash -ex

id $(whoami)

echo "Installing liquid" > /dev/null

cd /opt/node
sudo chown -R vagrant: .

mkdir volumes
mkdir collections
if ! [ -d collections/testdata ]; then
  git clone https://github.com/hoover/testdata collections/testdata
fi

cp examples/liquid.ini .

./liquid resources
./liquid deploy

echo "Liquid provisioned successfully." > /dev/null
