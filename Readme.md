# Liquid Investigations Node

Scripts and configuration to run a Liquid Node

[![Build Status](https://jenkins.liquiddemo.org/api/badges/liquidinvestigations/node/status.svg)](https://jenkins.liquiddemo.org/liquidinvestigations/node)


## Installation

Clone this repository, `cd` into it, `git checkout` the tag of the latest
release. The `master` branch is the latest development version, do not use in
production.


### Dependencies

The Liquid bundle runs inside a Nomad cluster, see [docs/Cluster.md](docs/Cluster.md)
for instructions.

Install system dependencies:

```shell
sudo apt update
sudo apt install -y python3-venv python3-pip git curl unzip
sudo pip3 install pipenv
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.d/es.conf
sudo sysctl --system
```

Then, install Python dependencies:

```shell
pipenv install
```

### Configuration

The Liquid Investigations cluster configuration is read from `liquid.ini`. See
[docs/Configuration.md](docs/Configuration.md) for details. Start with the
example configuration file:

```shell
cp examples/liquid.ini .
```

### Deployment

The `deploy` command pushes the configuration to the cluster. It configures
secrets, starts all the apps, and triggers collection processing. Run it
whenever you make changes to the configuration:

```shell
./liquid deploy
```

The liquid instance will listen by default on port 80 on the local machine. If
you don't have a DNS domain pointing to the macine, you can add entries to
`/etc/hosts`:

```
10.66.60.1 liquid.example.org
10.66.60.1 hoover.liquid.example.org
...
```

HTTPS, if configured, may take a few hours to obtain certificates for all the
domains.

### Final steps

#### Create an initial admin user

```shell
./liquid shell liquid:core ./manage.py createsuperuser
```

If two-factor authentication was enabled (`two_factor_auth = true` in `liquid.ini`), then create an invitation for the initial admin user and use it to set up your device:

```shell
./liquid shell liquid:core ./manage.py invite first_admin_user
```

#### Configure RocketChat Authentication

Rocketchat, if enabled, requires a manual step for setting up the Single Sign-On: [docs/RocketChat.md#set-up-authentication](docs/RocketChat.md#set-up-authentication)

#### Optionally, Download Maps

Maps take a long time to download and require 120 GB of extra storage.

Instructions here: [docs/Maps.md](docs/Maps.md)


## Maintenance
For instructions and best practices on running a liquid node, see
[docs/Maintenance.md](docs/Maintenance.md).


## Development
You can enable debugging, modify code for the applications, and more, see
[docs/Development.md](docs/Development.md).

To develop hoover-ui locally, see
[Hoover Readme](https://github.com/liquidinvestigations/hoover-ui)

To avoid running the cluster locally, you can use Vagrant, see
[docs/Vagrant.md](docs/Vagrant.md).


## Bundled applications
* [RocketChat](docs/RocketChat.md)
* [Hoover](docs/Hoover.md)
* [Nextcloud](docs/Nextcloud.md)
* [Hypothesis](docs/Hypothesis.md)
* DokuWiki
* CodiMD
