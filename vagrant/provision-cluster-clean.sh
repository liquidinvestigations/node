#!/bin/bash -ex

if [ $EUID -eq 0 ]; then
  chmod 755 $0
  echo "I'm root, switching to vagrant." > /dev/null
  exec sudo -iu vagrant $0
fi

echo "Hello, my name is $(whoami), PID=$$." > /dev/null

echo "Preparing the system" > /dev/null

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -yqq git python3 unzip docker.io supervisor python3-venv
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.d/es.conf
sudo sysctl --system
sudo adduser vagrant docker
sudo chown vagrant /opt

echo "Installing the cluster" > /dev/null

if [ ! -d /opt/cluster ]; then
  git clone https://github.com/liquidinvestigations/cluster /opt/cluster
  cd /opt/cluster
  mkdir -p /opt/var/cluster/var
  ln -s /opt/var/cluster/var
fi

echo "Cluster installed successfully." > /dev/null
