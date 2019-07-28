#!/usr/bin/env bash

set -e

cd "$( dirname "${BASH_SOURCE[0]}" )"

cp registry-daemon.json /etc/docker/daemon.json
systemctl restart docker
