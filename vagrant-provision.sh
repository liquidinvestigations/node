#!/bin/bash -e

nomad_version="0.8.7"
consul_version="1.4.3"

mkdir -p /opt/cluster

echo "Installing dependencies"
(
set -x
apt-get install -qqy unzip supervisor apt-transport-https \
  gnupg2 software-properties-common dirmngr
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
add-apt-repository ppa:deadsnakes/ppa -y
apt-get update -qq
apt-get install -qqy docker-ce python3.7
adduser vagrant docker
cd /usr/bin
rm -f python3
ln -s /usr/bin/python3.7 python3
)

echo "Installing Consul and Nomad"
(
cd /opt/cluster
set -x
curl -OLs https://releases.hashicorp.com/nomad/${nomad_version}/nomad_${nomad_version}_linux_amd64.zip
curl -OLs https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip
rm -f nomad consul
unzip nomad_${nomad_version}_linux_amd64.zip
unzip consul_${consul_version}_linux_amd64.zip
cd /usr/local/bin
rm -f nomad consul
ln -s /opt/cluster/nomad /opt/cluster/consul .
)

echo "Configuring Nomad"
(
interface=$(ip route get 8.8.8.8 | awk '{ print $5; exit }')
echo "Detected main network interface ${interface}"
cat <<EOF | sed -e 's/^  //' > /opt/cluster/nomad.hcl
  bind_addr = "0.0.0.0"
  advertise {
    http = "{{ GetInterfaceIP \`$interface\` }}"
    serf = "{{ GetInterfaceIP \`$interface\` }}"
  }
  client {
    enabled = true
    network_interface = "$interface"
  }
EOF
)

echo "Configuring supervisor"
(
cat <<EOF | sed -e 's/^  //' > /etc/supervisor/conf.d/cluster.conf
[program:nomad]
user = vagrant
command = /opt/cluster/nomad agent -dev -config=/opt/cluster/nomad.hcl
redirect_stderr = true

[program:consul]
user = vagrant
command = /opt/cluster/consul agent -dev
redirect_stderr = true
EOF
set -x
supervisorctl update
)
