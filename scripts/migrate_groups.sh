#!/bin/bash -x

cd "$(dirname ${BASH_SOURCE[0]})/.."

LIQUID_GROUPS=$(./liquid shell liquid:core \
                       bash -c 'sqlite3 ./var/db.sqlite3 "select name from auth_group;"')

for g in $LIQUID_GROUPS; do
    # sqlite outputs the names like: username\r so we remove the trailing carriage return.
    LIQUID_GROUP=$(echo $g | sed -e 's/\r//')
    # $LIQUID_DOMAIN is an environment variable inside the wikijs container so we escape it here
    ./liquid shell wikijs:wikijs \
             bash -c "node /wiki/create-group.js $LIQUID_GROUP || true"
    if [[ $? -ne 0 ]]; then
        echo "Could not create group: ${LIQUID_GROUP}!"
    fi
done
