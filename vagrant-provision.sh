#!/bin/bash -e


echo "Preparing the system"
(
apt-get update -qq
apt install -yqq sudo git python3 unzip docker.io supervisor
echo 'vm.max_map_count=262144' > /etc/sysctl.d/es.conf
sysctl --system
adduser --disabled-password --GECOS 'Liquid Investigations,,,' liquid
adduser liquid sudo
adduser liquid docker
chgrp liquid /opt
chmod g+w /opt
)

echo "Installing the nomad cluster"
(
git clone https://github.com/liquidinvestigations/cluster /opt/cluster
cd /opt/cluster
cat > cluster.ini <<EOF
[nomad]
address = 0.0.0.0
[supervisor]
autostart = on
EOF
./cluster.py install
./cluster.py configure
sudo ln -s `pwd`/etc/supervisor-cluster.conf /etc/supervisor/conf.d/cluster.conf
sudo supervisorctl update
)

echo "Installing liquid"
(
git clone https://github.com/liquidinvestigations/node /opt/node
cd /opt/node
cat > liquid.ini <<EOF
[liquid]
domain = liquid.example.com
EOF
sudo mkdir -p volumes/hoover/es/data
sudo chown -R 1000:1000 volumes/hoover/es/data
./liquid.py deploy
)
