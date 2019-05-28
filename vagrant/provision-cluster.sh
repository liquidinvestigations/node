#!/bin/bash -ex

if [ $EUID -eq 0 ]; then
  chmod 755 $0
  echo "I'm root, switching to vagrant." > /dev/null
  exec sudo -iu vagrant $0
fi

echo "Hello, my name is $(whoami), PID=$$." > /dev/null

echo "Installing the nomad cluster" > /dev/null

if ! [ -d /opt/cluster ]; then
  git clone https://github.com/liquidinvestigations/cluster /opt/cluster
fi
cd /opt/cluster

sudo ./examples/network.sh
cp examples/cluster.ini .
./examples/docker.sh
sleep 20
docker exec cluster /opt/cluster/cluster.py autovault
