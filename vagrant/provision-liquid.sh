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
cat vagrant/liquid-collections.ini >> liquid.ini

./liquid resources
./liquid deploy

cp -f examples/liquid.ini .

./liquid collectionsgc
./liquid nomadgc

echo "Liquid provisioned successfully." > /dev/null
