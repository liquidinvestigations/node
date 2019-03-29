#!/bin/bash -e

nomad_version="0.8.7"
consul_version="1.4.3"

mkdir -p /opt/cluster

echo "Dependencies"
(
set -x
apt-get update
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
mkdir /var/local/cluster
chown vagrant: /var/local/cluster
)

echo "Consul"
(
cd /opt/cluster
curl -OLs https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip
rm -f consul
unzip consul_${consul_version}_linux_amd64.zip
cd /usr/local/bin
rm -f consul
ln -s /opt/cluster/consul .

cat <<EOF | sed -e 's/^  //' > /opt/cluster/consul.hcl
  bind_addr = "127.0.0.1"
  data_dir = "/var/local/cluster/consul"

  datacenter = "dc1"
  server = true
  ui = true
  bootstrap_expect = 1
EOF
)

echo "Nomad"
(
cd /opt/cluster
rm -f nomad
curl -OLs https://releases.hashicorp.com/nomad/${nomad_version}/nomad_${nomad_version}_linux_amd64.zip
unzip nomad_${nomad_version}_linux_amd64.zip
cd /usr/local/bin
rm -f nomad
ln -s /opt/cluster/nomad

interface=$(ip route get 8.8.8.8 | awk '{ print $5; exit }')
echo "Detected main network interface ${interface}"

cat <<EOF | sed -e 's/^  //' > /opt/cluster/nomad.hcl
  bind_addr = "0.0.0.0"
  data_dir = "/var/local/cluster/nomad"

  leave_on_interrupt = true
  leave_on_terminate = true
  disable_update_check = true

  advertise {
    http = "{{ GetInterfaceIP \`$interface\` }}"
    serf = "{{ GetInterfaceIP \`$interface\` }}"
  }

  server {
    enabled = true
    bootstrap_expect = 1
  }

  client {
    enabled = true
    network_interface = "$interface"
  }
EOF
)

echo "Supervisor"
(
cat <<EOF | sed -e 's/^  //' > /etc/supervisor/conf.d/cluster.conf
  [program:nomad]
  user = vagrant
  command = /opt/cluster/nomad agent -config /opt/cluster/nomad.hcl
  redirect_stderr = true

  [program:consul]
  user = vagrant
  command = /opt/cluster/consul agent -config-file /opt/cluster/consul.hcl
  redirect_stderr = true
EOF
set -x
supervisorctl update
)

echo "Increasing vm.max_map_count"
(
set -x
cd /etc/sysctl.d
echo "vm.max_map_count=262144" > liquid.conf
echo 262144 > /proc/sys/vm/max_map_count
)

echo "Elasticsearch data dir"
(
es_data=/var/local/liquid/volumes/hoover/es/data
set -x
mkdir -p "$es_data"
chown 1000:1000 "$es_data"
)
