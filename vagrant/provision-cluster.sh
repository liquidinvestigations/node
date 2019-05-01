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


echo "Installing the nomad cluster" > /dev/null

if ! [ -d /opt/cluster ]; then
  git clone https://github.com/liquidinvestigations/cluster /opt/cluster
fi
cd /opt/cluster

if ! [ -e var ]; then
  mkdir -p /opt/var/cluster/var
  ln -s /opt/var/cluster/var
fi

sudo mv /tmp/vagrant-cluster.ini cluster.ini

if ! [ -e bin ]; then
  ./cluster.py install
  sudo setcap cap_ipc_lock=+ep bin/vault
fi

./cluster.py configure

echo "Installing the cluster in supervisor" > /dev/null
etc_cluster_conf=etc/supervisor/conf.d/cluster.conf
if ! [ -e $etc_cluster_conf ]; then
  sudo ln -s `pwd`/etc/supervisor-cluster.conf $etc_cluster_conf
fi
sudo supervisorctl update

echo "Reticulating splines" > /dev/null

sudo supervisorctl restart cluster:consul cluster:vault
./cluster.py autovault
sudo supervisorctl restart cluster:nomad

echo "Cluster provisioned successfully." > /dev/null
