Create a configuration file, `nomad-agent.hcl`, with the following content,
adapted to your machine in case `eth0` is not the main network interface:

```hcl
advertise {
  http = "{{ GetInterfaceIP `eth0` }}"
  serf = "{{ GetInterfaceIP `eth0` }}"
}

client {
  enabled = true
  network_interface = "eth0"
}
```

```shell
consul agent -dev &
nomad agent -dev -config=nomad-agent.hcl &
nomad job run liquid.nomad
open http://$IP # IP address of your machine
```

### Hoover
To start a snoop for the `testdata` collection:
```shell
git clone https://github.com/hoover/testdata
mkdir -p /var/local/liquid/collections
ln -s $(pwd)/testdata/data /var/local/liquid/collections/testdata
nomad job run snoop-testdata.nomad
```

To log into the snoop docker container for testdata:
```shell
./crowbar.py shell snoop-testdata-api
```
