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
sg docker newgrp `id -gn`
sudo chown vagrant /opt


echo "Installing the nomad cluster" > /dev/null

git clone https://github.com/liquidinvestigations/cluster /opt/cluster
cd /opt/cluster

cat > cluster.ini <<EOF
[nomad]
address = 0.0.0.0

[supervisor]
autostart = true
EOF

./cluster.py install
sudo setcap cap_ipc_lock=+ep bin/vault
./cluster.py configure
sudo ln -s `pwd`/etc/supervisor-cluster.conf /etc/supervisor/conf.d/cluster.conf
sudo supervisorctl update

./cluster.py autovault
sudo supervisorctl restart cluster:nomad

echo "Cluster provisioned successfully." > /dev/null
