#!/bin/bash

set -ex
set -o pipefail

if [ -z "$MYSQL_HOST" ]; then
    echo "Missing MYSQL_HOST - please wait for the DB to spin up before running setup"
    exit 1
fi
echo "MYSQL_HOST: $MYSQL_HOST"

cd /var/www/html

set +e
# `php occ status --output=json` returns something like "Nextcloud is not
# installed" + JSON, creating a JSON parse Error; `jq` fill fail thus saving
# $INSTALLED as "error". Using `pipefail` we can capure  errors of `php status`
# too as the "error" value in $INSTALLED.
php occ status --output=json
INSTALLED=$( set -o pipefail; php occ status --output=json | jq '.installed' || echo "error" )
set -e

echo "INSTALLED STATE: $INSTALLED"


if [[ "$INSTALLED" =~ "false" || "$INSTALLED" =~ "error" ]]; then
    echo "Installing nextcloud"

    php occ maintenance:install \
            --no-interaction \
            --verbose \
            --database mysql \
            --database-name $MYSQL_DB \
            --database-host $MYSQL_HOST \
            --database-user $MYSQL_USER \
            --database-pass $MYSQL_PASSWORD \
            --admin-user=$NEXTCLOUD_ADMIN_USER \
            --admin-pass=$NEXTCLOUD_ADMIN_PASSWORD

    (
    set +x
    export OC_PASS="$UPLOADS_USER_PASSWORD"
    php occ user:add --password-from-env --display-name="uploads" uploads
    php occ config:system:set trusted_domains 0 --value '*'
    )

    echo "Installation Successful"
fi

# check again if installation ok 
set +e
php occ status --output=json
INSTALLED=$( set -o pipefail; php occ status --output=json | jq '.installed' || echo "error" )
set -e
if ! [[ "$INSTALLED" =~ "true"  ]]; then
    echo "NEXTCLOUD STILL NOT INSTALLED : $INSTALLED"
    exit 1
fi

if [[ "$INSTALLED" =~ "true" || "$INSTALLED" =~ "error" ]]; then
    echo "Trying to upgrade nextcloud"
    php occ upgrade --no-interaction || true
    php occ app:update --no-interaction --all || true
    echo "Upgrade Successful"
fi


echo "Configuring..."
php occ config:system:set trusted_domains 0 --value '*'
php occ config:system:set dbhost --value $MYSQL_HOST
php occ config:system:set overwrite.cli.url --value $HTTP_PROTO://$NEXTCLOUD_HOST
php occ config:system:set allow_user_to_change_display_name --value false --type boolean
php occ config:system:set overwritehost --value $NEXTCLOUD_HOST
php occ config:system:set overwriteprotocol --value $HTTP_PROTO
php occ config:system:set htaccess.RewriteBase --value '/'
php occ config:system:set skeletondirectory --value ''
php occ config:system:set updatechecker --value false --type boolean
php occ config:system:set has_internet_connection --value true --type boolean
php occ config:system:set appstoreenabled --value true --type boolean

echo "Unpacking theme"
rm -rf themes/liquid || true
cp -r /liquid/theme themes/liquid
chown -R www-data:www-data themes/liquid
chmod g+s themes/liquid

php occ config:system:set theme --value liquid

#install contacts before shutting down the app store
php occ app:install contacts || true
php occ app:install calendar || true
php occ app:install deck     || true
php occ app:install polls    || true

php occ app:enable  calendar
php occ app:enable  contacts
php occ app:disable theming
php occ app:disable accessibility
php occ app:disable activity
php occ app:disable comments
php occ app:disable federation
php occ app:enable files_pdfviewer
php occ app:disable files_versions
php occ app:disable files_videoplayer
php occ app:disable files_sharing
php occ app:disable firstrunwizard
php occ app:disable gallery
php occ app:disable nextcloud_announcements
php occ app:disable notifications
php occ app:disable password_policy
php occ app:disable sharebymail
php occ app:disable support
php occ app:disable survey_client
php occ app:disable systemtags
php occ app:disable updatenotification

php occ config:system:set has_internet_connection --value false --type boolean
php occ config:system:set appstoreenabled --value false --type boolean

echo "Configuration done"

(
set +x
export OC_PASS="$UPLOADS_USER_PASSWORD"
php occ user:resetpassword --password-from-env uploads
export OC_PASS="$NEXTCLOUD_ADMIN_PASSWORD"
php occ user:resetpassword --password-from-env $NEXTCLOUD_ADMIN_USER
)
echo "uploads and admin password set
"
