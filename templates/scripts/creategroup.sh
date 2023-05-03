#!/bin/sh
apt-get install pip
pip install requests
set -ex

LIQUID_GROUP=$1

echo "Creating group '$LIQUID_GROUP' for wiki.js."

if [ "$WIKIJS_ENABLED" = "True" ] ; then
    echo "Creating wiki.js user..."
    ${exec_command('wikijs:wikijs', 'node', '/wiki/create-group.js', '${LIQUID_GROUP}')}
fi
