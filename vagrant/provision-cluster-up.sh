#!/bin/bash -ex

if [ $EUID -eq 0 ]; then
  chmod 755 $0
  echo "I'm root, switching to vagrant." > /dev/null
  exec sudo -iu vagrant $0
fi

echo "Hello, my name is $(whoami), PID=$$." > /dev/null

echo "Configuring the cluster" > /dev/null

cd /opt/cluster
./cluster.py install
sudo setcap cap_ipc_lock=+ep bin/vault
./cluster.py configure

echo "Installing the cluster in supervisor" > /dev/null

supervisord_cluster='/etc/supervisor/conf.d/cluster.conf'
sudo rm -f $supervisord_cluster
sudo ln -s `pwd`/etc/supervisor-cluster.conf $supervisord_cluster
sudo supervisorctl update

echo "Reticulating splines" > /dev/null

sudo supervisorctl start cluster:consul cluster:vault
./cluster.py autovault
sudo supervisorctl restart cluster:nomad

echo "Cluster provisioned successfully." > /dev/null
