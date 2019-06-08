#!/bin/bash -ex

if ! docker version; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -yqq git python3 unzip docker.io supervisor python3-venv
  echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.d/es.conf
  sysctl --system
  adduser vagrant docker
fi

chown vagrant: /opt

echo "Installing the nomad cluster" > /dev/null

if ! [ -d /opt/cluster ]; then
  sudo -u vagrant git clone https://github.com/liquidinvestigations/cluster /opt/cluster
fi
cd /opt/cluster

if ! ip a | grep -q liquid-bridge; then
  ./examples/network.sh
fi

echo "Patching configuration..." > /dev/null
sudo -u vagrant cp examples/cluster.ini .
sed -i '/\[nomad\]/a memory = 16660' cluster.ini
cat cluster.ini

echo "Running the cluster" > /dev/null
sudo -Hu vagrant ./examples/docker.sh
sleep 10
until docker exec cluster /opt/cluster/cluster.py autovault; do sleep 10; done
sleep 10
