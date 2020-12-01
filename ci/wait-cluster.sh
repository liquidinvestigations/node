#!/bin/bash -e

cd /opt/node
sudo chown -R vagrant: .
mkdir volumes
mkdir collections
sudo pip3 install pipenv &> /dev/null
pipenv install &> /dev/null

echo "Waiting for Docker..."
until docker version --format 'docker s={{.Server.Version}} c={{.Client.Version}}'; do sleep 2; done

echo "Waiting for cluster autovault..."
until docker ps | grep -q cluster; do sleep 2; done
sleep 2
docker exec cluster ./cluster.py wait &> /dev/null
echo "Cluster provision done."
