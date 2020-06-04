#!/bin/bash

set -ex
set -o pipefail

if [ -z "$POSTGRES_HOST" ]; then
    echo "Missing POSTGRES_HOST - please wait for the DB to spin up before running setup"
    sleep 17
    exit 1
fi

# https://github.com/nextcloud/docker/issues/820#issuecomment-515898904
while ! pgrep -x "apache2" > /dev/null ; do
    sleep 1
done

cd /var/www/html

php occ status --output=json
# `php occ status --output=json` returns something like "Nextcloud is not
# installed" + JSON, creating a JSON parse Error; `jq` fill fail thus saving
# $INSTALLED as "error". Using `pipefail` we can capure  errors of `php status`
# too as the "error" value in $INSTALLED.

set +e
INSTALLED=$( set -o pipefail; php occ status --output=json | tail -n 1 | jq '.installed' || echo "error" )
set -e

if [[ "$INSTALLED" =~ "true" || "$INSTALLED" =~ "error" ]]; then
    echo "Trying to upgrade nextcloud"
    php occ upgrade --no-interaction || true
    php occ app:update --no-interaction --all || true
fi


set +e
INSTALLED=$( set -o pipefail; php occ status --output=json | tail -n 1 | jq '.installed' || echo "error" )
set -e


if [[ "$INSTALLED" =~ "false" || "$INSTALLED" =~ "error" ]]; then
    echo "Installing nextcloud"

    php occ maintenance:install \
            --no-interaction \
            --verbose \
            --database pgsql \
            --database-name $POSTGRES_DB \
            --database-host $POSTGRES_HOST \
            --database-user $POSTGRES_USER \
            --database-pass $POSTGRES_PASSWORD \
            --admin-user=$NEXTCLOUD_ADMIN_USER \
            --admin-pass=$NEXTCLOUD_ADMIN_PASSWORD

    echo "Installation successful"
fi

echo "Configuring..."
php occ maintenance:mode --on

php occ config:system:set trusted_domains 0 --value '*'
php occ config:system:set dbhost --value $POSTGRES_HOST
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

php occ app:disable accessibility
php occ app:disable activity
php occ app:disable comments
php occ app:disable federation
php occ app:disable files_sharing
php occ app:disable files_versions
php occ app:disable files_videoplayer
php occ app:disable firstrunwizard
php occ app:disable gallery
php occ app:disable nextcloud_announcements
php occ app:disable notifications
php occ app:disable password_policy
php occ app:disable sharebymail
php occ app:disable support
php occ app:disable survey_client
php occ app:disable systemtags
php occ app:disable theming
php occ app:disable updatenotification

php occ app:enable  calendar
php occ app:enable  contacts
php occ app:enable files_pdfviewer

php occ config:system:set has_internet_connection --value false --type boolean
php occ config:system:set appstoreenabled --value false --type boolean

echo "Configuration done"


USERNAME=uploads
if ! ( php occ user:list | grep -q "$USERNAME" ); then
  set +x
  export OC_PASS="$UPLOADS_USER_PASSWORD"
  set -x

  # avoid the error 'Username is invalid because files already exist for this user'
  # see https://github.com/nextcloud/server/issues/21144
  rm -vrf "/var/www/html/data/$USERNAME/files"
  rm -vrf "/var/www/html/data/$USERNAME"

  php occ user:add --password-from-env --display-name="$USERNAME" $USERNAME
  mkdir -p /var/www/html/data/$USERNAME
  # error: can't follow symlinks when running files:scan
  # ln -s /data /var/www/html/data/$USERNAME/files

  echo "$USERNAME user created"
fi

# mount and chown run by www-data is passwordless in /etc/sudoers, check dockerfile
mkdir -p /var/www/html/data/$USERNAME/files
sudo /bin/chown www-data: /data
sudo /bin/chown www-data: /var/www/html/data/$USERNAME/files
# permission denied without CAP_SYS_ADMIN and docker run --privileged:
sudo /bin/mount --rbind /data /var/www/html/data/$USERNAME/files

(
  set +x
  export OC_PASS="$UPLOADS_USER_PASSWORD"
  set -x
  php occ user:resetpassword --password-from-env $USERNAME

  set +x
  export OC_PASS="$NEXTCLOUD_ADMIN_PASSWORD"
  set -x
  php occ user:resetpassword --password-from-env $NEXTCLOUD_ADMIN_USER
)
echo "$USERNAME and admin password set"

php occ maintenance:mode --off

# scan the filesystem in case there are files initially (redeploy e.g.)
php occ files:scan --all

set +x
echo "waiting for apache to die..."
while pgrep -x "apache2" > /dev/null ; do
    sleep 10
done
echo "apache died"
