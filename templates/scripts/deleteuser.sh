#!/bin/sh
apt-get install pip
pip install requests
set -ex

LIQUID_USER=$1

echo "Deleting user '$LIQUID_USER' for all enabled apps."

if [ "$HOOVER_ENABLED" = "True" ] ; then
    ${exec_command('hoover:search', './manage.py', 'deleteuser', '$LIQUID_USER')}
    echo "Deleted Hoover user..."
fi

if [ "$ROCKETCHAT_ENABLED" = "True" ] ; then
    python local/delete_rocket_user.py $LIQUID_USER
    echo "Deleted Rocketchat user..."
fi

if [ "$CODIMD_ENABLED" = "True" ] ; then
    # this command is an extension to the codimd manage_users function in the liquid fork of it
    ${exec_command('codimd:codimd', '/codimd/bin/manage_users', '--liquiddel=$LIQUID_USER')}
    echo "Deleted CodiMD user..."
fi

if [ "$WIKIJS_ENABLED" = "True" ] ; then
    ${exec_command('wikijs:wikijs', 'node', '/wiki/delete-user.js', '$LIQUID_USER')}
    echo "Deleted wiki.js user..."
fi
