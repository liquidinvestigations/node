#!/bin/bash -ex

echo "Hello, my name is $(whoami)." > /dev/null

echo "Preparing the DigitalOcean droplet" > /dev/null

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -yqq jq

adduser --disabled-password --GECOS 'Vagrant,,,' vagrant
adduser vagrant sudo
echo '%sudo ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/vagrant


if [ ! -z "$DO_SEPPUKU" ]; then
  nohup /opt/node/vagrant/seppuku.sh > /tmp/seppuku.log 2>&1 &
  echo "Seppuku protocol enabled" > /dev/null
fi

echo "DigitalOcean provisioned successfully." > /dev/null
