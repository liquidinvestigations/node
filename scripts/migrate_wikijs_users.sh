#!/bin/bash -x

cd "$(dirname ${BASH_SOURCE[0]})/.."

USERS=$(./liquid shell liquid:core \
         bash -c 'sqlite3 ./var/db.sqlite3 "select username from auth_user;"')

echo $LIQUID_DOMAIN

for u in $USERS; do
    # sqlite outputs the names like: username\r so we remove the trailing carriage return.
    LIQUID_USER=$(echo $u | sed -e 's/\r//')
    # $LIQUID_DOMAIN is an environment variable inside the wikijs container so we escape it here
    ./liquid shell wikijs:wikijs \
             bash -c "node /wiki/create-user.js $LIQUID_USER@\$LIQUID_DOMAIN $LIQUID_USER || true"
    if [[ $? -ne 0 ]]; then
        echo "Could not create user: ${LIQUID_USER}!"
    fi
done
