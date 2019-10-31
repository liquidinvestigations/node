# Liquid Investigations Node

Scripts and configuration to run a Liquid Node

[![Build Status](https://jenkins.liquiddemo.org/api/badges/liquidinvestigations/node/status.svg)](https://jenkins.liquiddemo.org/liquidinvestigations/node)


## Installation

### Dependencies

The Liquid bundle runs inside a cluster, see [docs/Cluster.md](docs/Cluster.md)
for instructions.

Install system dependencies:

```shell
sudo apt-get update
sudo apt-get install -y python3-venv python3-pip git curl unzip
sudo pip3 install pipenv
```

Clone this repository, `cd` into it, then install Python dependencies:

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

### Final steps

The liquid instance will listen by default on port 80 on the local machine. If
you don't have a DNS domain pointing to the macine, you can add entries to
`/etc/hosts`:

```
10.66.60.1 liquid.example.com
10.66.60.1 hoover.liquid.example.com
...
```

Create an initial admin user:
```shell
./liquid shell liquid-core ./manage.py createsuperuser
```

Configure RocketChat to use `liquid-core`'s oauth2 provider to authenticate
users:
[docs/RocketChat.md#set-up-authentication](docs/RocketChat.md#set-up-authentication)


## Development
You can enable debugging, modify code for the applications, and more, see
[docs/Development.md](docs/Development.md).

To avoid running the cluster locally, you can use Vagrant, see
[docs/Vagrant.md](docs/Vagrant.md).


## Bundled applications
* [RocketChat](docs/RocketChat.md)
* [Hoover](docs/Hoover.md)
* [Nextcloud](docs/Nextcloud.md)
* [Hypothesis](docs/Hypothesis.md)
* DokuWiki
* CodiMD
