#!/bin/sh
apt-get install pip
pip install requests
set -ex
liquid_domain="${liquid_domain}"
echo "Deleting user {% raw %}'${NOMAD_META_USERNAME}'{% endraw %} for all enabled apps."

{% if config.is_app_enabled('hoover') %}
${exec_command('hoover:search', './manage.py', 'deleteuser', '${NOMAD_META_USERNAME}')}
echo "Deleted Hoover user..."
{% endif %}

{% if config.is_app_enabled('rocketchat') %}
python local/delete_rocket_user.py {% raw %}${NOMAD_META_USERNAME}{% endraw %}
echo "Deleted Rocketchat user..."
{% endif %}

{% if config.is_app_enabled('codimd') %}
# this command is an extension to the codimd manage_users function in the liquid fork of it
${exec_command('codimd:codimd', '/codimd/bin/manage_users', '--liquiddel=${NOMAD_META_USERNAME}')}
echo "Deleted CodiMD user..."
{% endif %}
