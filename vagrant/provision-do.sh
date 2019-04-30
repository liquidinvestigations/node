#!/bin/bash -ex

echo "Hello, my name is $(whoami)."

echo "Preparing the DigitalOcean droplet"

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -yqq jq

adduser --disabled-password --GECOS 'Vagrant,,,' vagrant
adduser vagrant sudo
echo '%sudo ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/vagrant

echo "Starting watchdog to kill droplet"
nohup /opt/node/vagrant/killdroplet.sh > /tmp/killdroplet.log 2>&1 &

echo "DigitalOcean provisioned successfully."
