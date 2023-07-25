#!/bin/bash -x

LIQUID_GROUPS=$(${exec_command('liquid:core', './manage.py', 'getgroups', 'nextcloud27')})

echo $LIQUID_GROUPS

for g in $LIQUID_GROUPS; do
    # sqlite outputs the names like: username\r so we remove the trailing carriage return.
    LIQUID_GROUP=$(echo $g | sed -e 's/\r//')
    command=$(cat <<DELIM
${exec_command('nextcloud27:nextcloud27', 'su', '-p', 'www-data', '-s', '/bin/bash', '-c', '@php occ group:add $LIQUID_GROUP@')}
DELIM
           )
    command=$(echo $command | sed 's,@,'\'',g')
    eval $command
    if [[ $? -ne 0 ]]; then
        echo "Could not create group: $LIQUID_GROUP!"
    fi
done
