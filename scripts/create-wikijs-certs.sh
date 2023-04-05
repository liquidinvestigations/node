#!/bin/bash -ex

cd "$(dirname ${BASH_SOURCE[0]})/.."

./liquid shell wikijs:wikijs \
    bash -c 'node /wiki/generate-certs.js'
