# Liquid Investigations Node

Scripts and configuration to run a Liquid Node

[![Build Status](https://travis-ci.org/liquidinvestigations/node.svg?branch=master)](https://travis-ci.org/liquidinvestigations/node)


## Requirements
Liquid Node requires a Nomad + Consul + Vault cluster where the software will
be deployed. There are a few options:

* [Install a Cluster Manually](#install-a-cluster-manually) - for production or
  barebones development setups
* [Install the Liquid Cluster](#install-the-liquid-cluster) - automated
  single-machine cluster, read the instructions before using in production
* [Use Vagrant](#use-vagrant) - run `vagrant up` and be happy


Whichever option you choose, you will also need to:

* Increase `vm.max_map_count` to at least `262144`, to make elasticsearch
  happy - see the docs about [elasticsearch in docker][] for details.
* Make sure you have Python >= 3.7 installed.

[elasticsearch in docker]: https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html#docker-cli-run-prod-mode


### Install a Cluster Manually
Download Consul, Vault and Nomad. For production environments follow their
manuals. For development run them all in `-dev` mode:

```shell
./consul agent -dev &
./vault agent -dev &
./nomad agent -dev &
```

### Install the Liquid Cluster
[liquidinvestigations/cluster][cluster] is a self-configuring cluster of Consul
+ Vault + Nomad. It's optimised for local development, testing, and
demo/staging servers.

[cluster]: https://github.com/liquidinvestigations/cluster

### Use Vagrant
You can run a full Liquid cluster in a local virtual machine using [Vagrant][].
The configuration has been tested with the [libvirt driver][] but should work
with the default VirtualBox driver as well.

1. [Install vagrant][]
2. `cd` to the `vagrant` subfolder, everything Vagrant-related happens in here:
    ```shell
    cd vagrant/
    ```
3. Start the VM:
    ```shell
    vagrant up
    ```

You can log into the vm using `vagrant ssh`. Optionally, install
[vagrant-env][], and set environment variables in an `.env` local file that
will be ignored by git.

Vagrant will forward the following http ports:
  * `guest: 80, host: 1380` - public web server
  * `guest: 8765, host: 18765` - internal web server
  * `guest: 8500, host: 18500` - consul
  * `guest: 8200, host: 18200` - vault
  * `guest: 4646, host: 14646` - nomad

[Vagrant]: https://www.vagrantup.com
[libvirt driver]: https://github.com/vagrant-libvirt/vagrant-libvirt
[Install vagrant]: https://www.vagrantup.com/docs/installation/
[vagrant-env]: https://github.com/gosuri/vagrant-env


## Configuration
The Liquid Investigations cluster configuration is read from `liquid.ini`.
Start with the example configuration file:

```shell
cp examples/liquid.ini .
vim liquid.ini
```

We need a way to access Vault. The simplest way is to use:
```ini
[liquid]
domain = liquid.example.org
debug = true

vault_secrets = /opt/cluster/var/vault-secrets.ini

[collection:testdata]
workers = 1
```

This assumes the `vault-secrets.ini` file exists and contains a vault token. It
will be generated by the `./cluster.py autovault` command, or you can create it
manually in a different location with the following contents:

```ini
[vault]
root_token = s.Cmro41vNI4wIndgrPqzlqOKY
```

Then deploy to the cluster:

```shell
./liquid deploy
```

The liquid instance will listen by default on port 80 on the local machine. If
you don't have a DNS domain pointing to the macine, you can add entries to
`/etc/hosts`:

```
10.0.0.1 liquid.example.com
10.0.0.1 hoover.liquid.example.com
...
```

Create an initial admin user:
```shell
./liquid shell liquid-core ./manage.py createsuperuser
```

### Testdata
Set up the `testdata` collection. First download the data:

```shell
mkdir -p collections
git clone https://github.com/hoover/testdata collections/testdata
```

Next define the collection in `liquid.ini`:

```ini
[collection:testdata]
workers = 1
```

Then redeploy liquid, run migrations, and tell `hoover-search` about the new
collection:

```shell
./liquid deploy
./liquid initcollection testdata
```

### Nextcloud

Tell liquid we want to run nextcloud and nc_sync jobs in `liquid.ini`:

```ini
[job:nextcloud]
template = templates/nextcloud.nomad

[collection:ncsync]
workers = 1
sync = true
```
 
and deploy with  
```shell
./liquid.py deploy
```  

Nextcloud runs on the subdomain nextcloud.<liquid_domain>

### Debugging
Set the debug flag in `liquid.ini`:
```ini
[liquid]
debug = on
```

Then redeploy (`./liquid deploy`).

To log into the snoop docker container for testdata:
```shell
./liquid shell snoop-testdata-api
```

To dump the nginx configuration:
```shell
nomad alloc fs $(./liquid alloc liquid nginx) nginx/local/core.conf
```

#### Working on components

In order to work on Hoover Search, Hoover Snoop, or Liquid Core, first clone the repositories:
```shell
cd repos
./clone.sh https  # or ./clone.sh ssh, based on preference
```

After that, set this flag in your configuration:

```ini
[liquid]
...
mount_local_repos = true
```

#### Running custom jobs
You can deploy your own jobs on the cluster. First, create a nomad job file,
you can use one of the existing `.nomad` files as a starting point. Save it in
the `local` folder, or outside the repository, so that it doesn't interfere
with updates. Then add the job to `liquid.ini`:

```ini
[job:foo]
template = local/foo.nomad
```

Afterwards, run `./liquid deploy`, which will send your job `foo` to nomad.
