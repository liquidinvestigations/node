#!/bin/bash


chown -R www-data:www-data /var/www/html
chmod -R 775 /var/www/html

# Let /entrypoint.sh not run apache
sed -i 's/exec "$@"//g' /entrypoint.sh

# create file to override config
cat > /var/www/html/config/liquid.override.config.php << 'DELIM'
<?php
$CONFIG = array (
  'dbhost' =>  getenv('MYSQL_HOST'),
  'trusted_domains' => [
                    "localhost",
                    getenv('NEXTCLOUD_HOST'),
                    getenv('LIQUID_BASE_IP')
],
  'dbname' => getenv('MYSQL_DATABASE'),
  'dbpassword' => getenv('MYSQL_PASSWORD'),
);
DELIM

# Launch canonical entrypoint
/entrypoint.sh apache2-foreground

# Function from the Nextcloud's original entrypoint
run_as() {
    if [ "$(id -u)" = 0 ]; then
        su -p www-data -s /bin/bash -c "$1"
    else
        sh -c "$1"
    fi
}

run_as 'php occ app:getpath sociallogin'

exit_code=$?
if [ $exit_code -eq 0 ]; then
    echo "Sociallogin already installed."
else
    echo "Installing sociallogin"
    mkdir -p /var/www/html/custom_apps/sociallogin
    mv /apps-to-install/nextcloud-social-login-*/* /var/www/html/custom_apps/sociallogin
    run_as 'php occ app:enable sociallogin'
fi

chown -R www-data:www-data /var/www/html
chmod -R 775 /var/www/html


run_as "php occ config:system:set dbhost --value $MYSQL_HOST"

OAUTH_SETTINGS=$(cat << DELIM
'{"custom_oauth2":
[
{"name":"$OAUTH2_PROVIDER_NAME",
"title":"$OAUTH2_PROVIDER_TITLE",
"apiBaseUrl":"$OAUTH2_BASE_URL",
"authorizeUrl":"$OAUTH2_AUTHORIZE_URL",
"tokenUrl":"$OAUTH2_TOKEN_URL",
"profileUrl":"$OAUTH2_PROFILE_URL",
"logoutUrl":"$OAUTH2_LOGOUT_URL",
"clientId":"$OAUTH2_CLIENT_ID",
"clientSecret":"$OAUTH2_CLIENT_SECRET",
"scope":"read",
"profileFields":"$OAUTH2_PROFILE_FIELDS",
"displayNameClaim":"$OAUTH2_NAME_FIELD",
"groupsClaim":"$OAUTH2_GROUPS_CLAIM",
"style":"",
"defaultGroup":"",
"groupMapping":{"$OAUTH2_ADMIN_GROUP":"admin"}}
]}'
DELIM
)

run_as "php occ config:app:set sociallogin custom_providers --value=$OAUTH_SETTINGS"


run_as 'php occ config:app:set sociallogin auto_create_groups --value=0'

run_as 'php occ config:app:set sociallogin hide_default_login --value=1'
run_as 'php occ config:app:set sociallogin update_profile_on_login --value=1'

run_as 'php occ config:app:set settings profile_enabled_by_default --value=0'

run_as 'php occ config:app:set dav generateBirthdayCalendar --value "no"'
run_as 'php occ config:app:set dav sendEventReminders --value "no"'
run_as 'php occ config:app:set dav sendReminders --value "no"'
run_as 'php occ config:app:set dav sendInvitations --value "no"'

run_as 'php occ config:app:set contacts allowSocialSync --value "no"'

run_as 'php occ config:app:set core shareapi_allow_links --value="no"'
run_as 'php occ config:app:set core shareapi_allow_resharing --value="no"'
run_as 'php occ config:app:set core shareapi_allow_share_dialog_user_enumeration --value="no"'
run_as 'php occ config:app:set core shareapi_restrict_user_enumeration_full_match --value="no"'

run_as 'php occ config:app:set files_sharing incoming_server2server_share_enabled --value="no"'
run_as 'php occ config:app:set files_sharing lookupServerEnabled --value="no"'
run_as 'php occ config:app:set files_sharing lookupServerUploadEnabled --value="no"'
run_as 'php occ config:app:set files_sharing outgoing_server2server_share_enabled --value="no"'

run_as 'php occ config:system:set social_login_auto_redirect --value=true'
run_as 'php occ config:system:set skeletondirectory'
run_as "php occ config:app:set sociallogin custom_providers --value=$OAUTH_SETTINGS"

run_as 'php occ app:install calendar'
run_as 'php occ app:install polls'
run_as 'php occ app:install contacts'
run_as 'php occ app:install richdocumentscode'
run_as 'php occ app:enable richdocumentscode'
run_as 'php occ app:install richdocuments'
run_as 'php occ app:enable richdocuments'

run_as 'php occ app:remove onlyoffice'

run_as 'php occ config:app:set richdocuments disable_certificate_verification --value="yes"'

run_as "php occ rich:setup -w $COLLABORA_IP -c $NEXTCLOUD_IP"

run_as 'php occ app:disable dashboard'
run_as 'php occ app:disable nextcloud_announcements'
run_as 'php occ app:disable firstrunwizard'
run_as 'php occ app:disable weather_status'
run_as 'php occ app:disable sharebymail'
run_as 'php occ app:disable federation'
run_as 'php occ app:disable updatenotification'

# Run the server
exec apache2-foreground
