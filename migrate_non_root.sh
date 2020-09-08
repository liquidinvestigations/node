#!/bin/bash

# if [[ ! -z $(docker ps -q) ]]; then
#         exit 1
# fi

mkdir -p /opt/node/volumes/liquid/core/var
mkdir -p /opt/node/volumes/snoop/blobs

chown -R 666:666 /opt/node/volumes/liquid/core/var
chown -R 666:666 /opt/node/volumes/snoop/blobs
