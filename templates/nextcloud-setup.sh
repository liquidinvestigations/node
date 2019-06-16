#!/bin/bash

set -ex

if [ -z "$NEXTCLOUD_INTERNAL_STATUS_URL" ]; then
    echo "Missing NEXTCLOUD_INTERNAL_STATUS_URL - please wait for apache to boot up"
    sleep 6
    exit 1
fi

if [ -z "$MYSQL_HOST" ]; then
    echo "Missing MYSQL_HOST - please wait for the DB to spin up before running setup"
    sleep 6
    exit 1
fi

INSTALLED=$(curl --silent --header "Host: $NEXTCLOUD_HOST" $NEXTCLOUD_INTERNAL_STATUS_URL | jq .installed)
if [ "$INSTALLED" == "false" ]; then
    echo "Installing nextcloud"

    php /var/www/html/occ maintenance:install \
            --no-interaction \
            --verbose \
            --database mysql \
            --database-name $MYSQL_DB \
            --database-host $MYSQL_HOST \
            --database-user $MYSQL_USER \
            --database-pass $MYSQL_PASSWORD \
            --admin-user=$NEXTCLOUD_ADMIN_USER \
            --admin-pass=$NEXTCLOUD_ADMIN_PASSWORD

    php occ user:add --password-from-env --display-name="uploads" uploads
    php occ config:system:set trusted_domains 0 --value '*'

    echo "Installation successful -- now restarting (aka failing) the migrate job"
    exit 66
elif [ "$INSTALLED" == "null" ]; then
    echo "Apache probably not accepting host header"
    sleep 6
    exit 1
fi


echo "Unpacking theme"

rm -rf /var/www/html/themes/liquid || true
cp -r /liquid/theme /var/www/html/themes/liquid
chown -R www-data:www-data /var/www/html/themes/liquid
chmod g+s /var/www/html/themes/liquid


echo "Configuring..."

php occ config:system:set trusted_domains 0 --value '*'
php occ config:system:set dbhost --value $MYSQL_HOST
php occ config:system:set theme --value liquid
php occ config:system:set overwrite.cli.url --value $HTTP_PROTO://$NEXTCLOUD_HOST
php occ config:system:set allow_user_to_change_display_name --value false --type boolean
php occ config:system:set overwritehost --value $NEXTCLOUD_HOST
php occ config:system:set overwriteprotocol --value $HTTP_PROTO
php occ config:system:set htaccess.RewriteBase --value '/'
php occ config:system:set skeletondirectory --value ''
php occ config:system:set updatechecker --value false --type boolean
php occ config:system:set has_internet_connection --value false --type boolean
php occ config:system:set appstoreenabled --value false --type boolean

php occ app:disable theming
php occ app:disable accessibility
php occ app:disable activity
php occ app:disable comments
php occ app:disable federation
php occ app:disable files_pdfviewer
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

echo "Configuration done"
