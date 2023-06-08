#!/bin/bash

# Launch canonical entrypoint
/entrypoint.sh

# Function from the Nextcloud's original entrypoint
run_as() {
    if [ "$(id -u)" = 0 ]; then
        su -p www-data -s /bin/bash -c "$1"
    else
        sh -c "$1"
    fi
}

run_as 'php occ app:install sociallogin'

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

#, "wikijs":wikijs", "codimd":"codimd", "nextcloud":"nextcloud"

run_as "php occ config:app:set sociallogin custom_providers --value=$OAUTH_SETTINGS"

# run_as 'php occ config:app:set sociallogin auto_create_groups --value=1'
run_as 'php occ config:app:set sociallogin hide_default_login --value=1'
run_as 'php occ config:app:set sociallogin update_profile_on_login --value=1'
run_as 'php occ config:system:set social_login_auto_redirect --value=true'


run_as 'php occ app:install calendar'
run_as 'php occ app:install contacts'
run_as 'php occ app:install onlyoffice'
run_as 'php occ app:install richdocumentscode'

# Run the server
exec /entrypoint.sh apache2-foreground
