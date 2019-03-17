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

Increase `vm.max_map_count` to at least `262144`, to make elasticsearch happy -
see [the official documentation][] for details.

[the official documentation]: https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html#docker-cli-run-prod-mode

Make sure you have Python >= 3.7 installed.

```shell
consul agent -dev &
nomad agent -dev -config=nomad-agent.hcl &
./liquid.py setdomain liquid.example.org
nomad job run liquid.nomad
open http://$IP # IP address of your machine
```

## Hoover

Start `hoover` and `hoover-ui`:

Set up hoover-search:

```shell
nomad job run hoover-ui.nomad
nomad job run hoover.nomad
./liquid.py shell hoover-search ./manage.py migrate
./liquid.py shell hoover-search ./manage.py createsuperuser
```

...and the `testdata` collection:

```shell
git clone https://github.com/hoover/testdata
mkdir -p /var/local/liquid/collections
ln -s $(pwd)/testdata/data /var/local/liquid/collections/testdata
nomad job run collection-testdata.nomad
# wait a few seconds for the docker containers to spin up
./liquid.py shell snoop-testdata-api ./manage.py migrate
./liquid.py shell snoop-testdata-api ./manage.py initcollection
```

Add the the `testdata` collection to `hoover-search`:
```shell
./liquid.py shell hoover-search ./manage.py addcollection testdata --index testdata http://$(./liquid.py nomad_address):8765/testdata/collection/json --public
```

### Debugging
Set debug flag in all apps:
```shell
./liquid.py setdebug on
```

To log into the snoop docker container for testdata:
```shell
./liquid.py shell snoop-testdata-api
```

To dump the nginx configuration:
```shell
nomad alloc fs $(./liquid.py alloc liquid nginx) nginx/local/core.conf
```

### Vagrant
You can run a full Liquid cluster in a local virtual machine using [Vagrant][].
The configuration has been tested with the [libvirt driver][] but should work
with the default VirtualBox driver as well.

After [installing vagrant][], run `vagrant up` to download, start and provision
the VM. It will expose port `80` as `1380` (the main website) and `4646` as
`14646` (Nomad's UI, useful for debugging). Then, log into the VM and deploy
some containers:

```shell
vagrant ssh
# opens a shell inside the VM

cd /vagrant
./liquid.py setdebug on
./liquid.py setdomain liquid.example.org
nomad job run liquid.nomad
# ...
```

[Vagrant]: https://www.vagrantup.com
[libvirt driver]: https://github.com/vagrant-libvirt/vagrant-libvirt
[installing vagrant]: https://www.vagrantup.com/docs/installation/
