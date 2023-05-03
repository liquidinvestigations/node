#!/bin/sh
apt-get install pip
pip install requests
set -ex

LIQUID_GROUP=$1

echo "Deleting user '$LIQUID_GROUP' for wiki.js."

if [ "$WIKIJS_ENABLED" = "True" ] ; then
    ${exec_command('wikijs:wikijs', 'node', '/wiki/delete-group.js', '$LIQUID_GROUP')}
    echo "Deleted wiki.js group..."
fi
