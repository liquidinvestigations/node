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

sudo apt install python3-venv python3-pip
pip3 install pipenv
pipenv install -r requirements.txt
pipenv run ./liquid.py resources
pipenv run ./liquid.py deploy

echo "Liquid provisioned successfully." > /dev/null
