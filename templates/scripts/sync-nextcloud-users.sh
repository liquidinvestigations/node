#!/bin/bash -x

USERS=$(${exec_command('liquid:core', './manage.py', 'getusers')})

for u in $USERS; do
    # sqlite outputs the names like: username\r so we remove the trailing carriage return.
    LIQUID_USER=$(echo $u | sed -e 's/\r//')
    # $LIQUID_DOMAIN is an environment variable inside the wikijs container so we escape it here
    PW=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32 ; echo '')
    command=$(cat <<DELIM
${exec_command('nextcloud27:nextcloud27', 'su', '-p', 'www-data', '-s', '/bin/bash', '-c', '@export OC_PASS=$PW && php occ user:add --password-from-env --display-name=$LIQUID_USER $LIQUID_USER@')}
DELIM
)
    command=$(echo $command | sed 's,@,'\'',g')
    eval $command
    if [[ $? -ne 0 ]]; then
        echo "Could not create user: $LIQUID_USER!"
    fi
done
