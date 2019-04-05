# Liquid in a Nomad cluster

Use the instructions in [the cluster repository](https://github.com/liquidinvestigations/cluster) to get a working setup with nomad and consul. This will only work for x64 Linux machines, so for MacOS read the next section.


## Setting up nomad and consul without [cluster](https://github.com/liquidinvestigations/cluster)

Create a configuration file, `nomad-agent.hcl`, with the following content,
adapted to your machine in case `en0` is not the main network interface:

```hcl
advertise {
  http = "{{ GetInterfaceIP `en0` }}"
  serf = "{{ GetInterfaceIP `en0` }}"
}

client {
  enabled = true
  network_interface = "en0"
}
```

Increase `vm.max_map_count` to at least `262144`, to make elasticsearch happy -
see [the official documentation][] for details.

[the official documentation]: https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html#docker-cli-run-prod-mode

Make sure you have Python >= 3.7 installed.

```shell
consul agent -dev &
nomad agent -dev -config=nomad-agent.hcl &
```

# Setup

The Liquid Investigations cluster configuration is read from `liquid.ini`. Start with the following:

```shell
cat > liquid.ini <<EOF
[liquid]
domain = liquid.example.org
EOF

./liquid.py deploy

open http://$IP # IP address of your machine
```

## Hoover
Set up `hoover-search`:

```shell
mkdir -p volumes/hoover/es/data
./liquid.py shell hoover-search ./manage.py migrate
./liquid.py shell hoover-search ./manage.py createsuperuser
```

### Testdata
Set up the `testdata` collection. First download the data:

```shell
mkdir -p collections
git clone https://github.com/hoover/testdata collections/testdata
```

Next, tell liquid we want to run the `collection-testdata` job in `liquid.ini`:

```ini
[collection:testdata]
workers = 3
```

Then redeploy liquid, run migrations, and tell `hoover-search` about the new
collection:

```shell
./liquid.py deploy
# ... wait for the containers to spin up
./liquid.py shell snoop-testdata-api ./manage.py migrate
./liquid.py shell snoop-testdata-api ./manage.py initcollection
./liquid.py shell hoover-search ./manage.py addcollection testdata --index testdata http://$(./liquid.py nomad_address):8765/testdata/collection/json --public
```

### Debugging
Set the debug flag in `liquid.ini`:
```ini
[liquid]
debug = on
```

Then redeploy (`./liquid.py deploy`).

To log into the snoop docker container for testdata:
```shell
./liquid.py shell snoop-testdata-api
```

To dump the nginx configuration:
```shell
nomad alloc fs $(./liquid.py alloc liquid nginx) nginx/local/core.conf
```

### Vagrant (out of date)

__Warning__: Scripts are out of date. These need to be updated to use [cluster](https://github.com/liquidinvestigations/cluster) inside the virtual machine.

You can run a full Liquid cluster in a local virtual machine using [Vagrant][].
The configuration has been tested with the [libvirt driver][] but should work
with the default VirtualBox driver as well.

After [installing vagrant][], run `vagrant up` to download, start and provision
the VM. It will expose port `80` as `1380` (the main website) and `4646` as
`14646` (Nomad's UI, useful for debugging). Then, log into the VM and deploy
some containers:

```shell
cat > liquid.ini <<EOF
[liquid]
domain = liquid.example.org
EOF

vagrant up
vagrant ssh # opens a shell inside the VM
```

Then, inside the VM:
```shell
cd /vagrant
./liquid.py deploy
```

[Vagrant]: https://www.vagrantup.com
[libvirt driver]: https://github.com/vagrant-libvirt/vagrant-libvirt
[installing vagrant]: https://www.vagrantup.com/docs/installation/
