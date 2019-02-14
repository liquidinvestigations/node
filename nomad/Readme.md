# Liquid in a Nomad cluster
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

Increase `vm.max_map_count` to at least 262144, to make elasticsearch happy -
see [the official documentation][] for details.
[the official documentation]: https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html#docker-cli-run-prod-mode

```shell
consul agent -dev &
nomad agent -dev -config=nomad-agent.hcl &
./crowbar.py setdomain liquid.example.org
nomad job run liquid.nomad
open http://$IP # IP address of your machine
```

## Hoover
Start a snoop for the `testdata` collection:
```shell
git clone https://github.com/hoover/testdata
mkdir -p /var/local/liquid/collections
ln -s $(pwd)/testdata/data /var/local/liquid/collections/testdata
nomad job run snoop-testdata.nomad
# wait a few seconds for the docker containers to spin up
./crowbar.py shell snoop-testdata-api ./manage.py migrate
./crowbar.py shell snoop-testdata-api ./manage.py initcollection
```

Set up hoover-search and add the `testdata` collection:
```shell
nomad job run hoover-ui.nomad
nomad job run hoover.nomad
./crowbar.py shell hoover-search ./manage.py migrate
./crowbar.py shell hoover-search ./manage.py createsuperuser
./crowbar.py shell hoover-search ./manage.py addcollection testdata --index testdata http://$(./crowbar.py nomad_address):8765/testdata/collection/json --public
```

### Debugging
Set debug flag in all apps:
```shell
./crowbar.py setdebug on
```

To log into the snoop docker container for testdata:
```shell
./crowbar.py shell snoop-testdata-api
```

To dump the nginx configuration:
```shell
nomad alloc fs $(./crowbar.py alloc liquid nginx) nginx/local/core.conf
```
