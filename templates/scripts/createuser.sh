#!/bin/sh
apt-get install pip
pip install requests
set -ex

LIQUID_USER=$1

echo "Creating user '$LIQUID_USER' for all enabled apps."

if [ "$HOOVER_ENABLED" = "True" ] ; then
    echo "Creating Hoover user..."
    ${exec_command('hoover:search', './manage.py', 'createuser', '$LIQUID_USER')}
fi

if [ "$ROCKETCHAT_ENABLED" = "True" ] ; then
    echo "Creating Rocketchat user..."
    python local/create_rocket_user.py $LIQUID_USER
fi

if [ "$CODIMD_ENABLED" = "True" ] ; then
    echo "Creating CodiMD user..."
    ${exec_command('codimd:codimd', '/codimd/bin/manage_users', '--profileid=$LIQUID_USER', '--domain="$LIQUID_DOMAIN"')}
fi
