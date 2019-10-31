#!/bin/bash -ex

id $(whoami)

echo "Installing liquid" > /dev/null

cd /opt/node
sudo chown -R vagrant: .

mkdir volumes
mkdir collections
if ! [ -d collections/testdata ]; then
  git clone https://github.com/liquidinvestigations/testdata collections/testdata
fi
cp -a collections/testdata collections/inactive

echo "Add some collections, check resources and deploy"
cp examples/liquid.ini .
cat vagrant/liquid-collections.ini >> liquid.ini
sudo apt-get install -qy python3-venv python3-pip
sudo -H pip3 install pipenv
pipenv install 
./liquid resources
./liquid deploy

./liquid launchocr testdata --periodic @yearly --nice 9 --workers 1 --threads_per_worker 1

echo "Turn workers off, others on, and deploy"
cp examples/liquid.ini .
cat vagrant/liquid-collections-alt.ini >> liquid.ini
./liquid resources
./liquid deploy --no-secrets

echo "Remove all collections, gc"
cp -f examples/liquid.ini .
./liquid collectionsgc
./liquid nomadgc
./liquid deploy --no-secrets --no-checks

echo "Disable some apps, deploy"
cp -f examples/liquid.ini .
cat vagrant/liquid-apps.ini >> liquid.ini
./liquid deploy --no-secrets

echo "Disable some more apps, gc"
echo "default_app_status = off" >> liquid.ini
./liquid gc

echo "Liquid provisioned successfully." > /dev/null
