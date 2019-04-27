#!/bin/bash -e

echo "Hello, my name is $(whoami)."

echo "Preparing the DigitalOcean droplet"

adduser --disabled-password --GECOS 'Vagrant,,,' vagrant
adduser vagrant sudo
echo '%sudo ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/vagrant

echo "DigitalOcean provisioned successfully."
