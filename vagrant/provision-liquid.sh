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

cat vagrant/liquid-apps.ini >> liquid.ini

./liquid deploy

echo "default_app_status = off" >> liquid.ini

./liquid gc

echo "Liquid provisioned successfully." > /dev/null
