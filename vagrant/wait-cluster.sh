#!/bin/bash -ex

echo "Waiting for Docker..."
until docker version; do sleep 3; done

echo "Waiting for cluster autovault..."
until docker exec cluster /opt/cluster/cluster.py autovault; do sleep 10; done

echo "Cluster provision done."
