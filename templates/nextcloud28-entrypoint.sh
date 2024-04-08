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
                    getenv('LIQUID_BASE_IP'),
                    getenv('COLLABORA_HOST'),
                    getenv('LIQUID_HOST'),
],
  'dbname' => getenv('MYSQL_DATABASE'),
  'dbpassword' => getenv('MYSQL_PASSWORD'),
  'allow_local_remote_servers' => true,
);
DELIM

cat > /var/www/html/lib/public/AppFramework/Http/ContentSecurityPolicy.php << DELIM
<?php
namespace OCP\AppFramework\Http;

/**
 * Class ContentSecurityPolicy is a simple helper which allows applications to
 * modify the Content-Security-Policy sent by Nextcloud. Per default only JavaScript,
 * stylesheets, images, fonts, media and connections from the same domain
 * ('self') are allowed.
 *
 * Even if a value gets modified above defaults will still get appended. Please
 * notice that Nextcloud ships already with sensible defaults and those policies
 * should require no modification at all for most use-cases.
 *
 * This class allows unsafe-inline of CSS.
 *
 * @since 8.1.0
 */
class ContentSecurityPolicy extends EmptyContentSecurityPolicy {
	/** @var bool Whether inline JS snippets are allowed */
	protected \$inlineScriptAllowed = false;
	/** @var bool Whether eval in JS scripts is allowed */
	protected \$evalScriptAllowed = false;
	/** @var bool Whether WebAssembly compilation is allowed */
	protected ?bool \$evalWasmAllowed = false;
	/** @var bool Whether strict-dynamic should be set */
	protected \$strictDynamicAllowed = false;
	/** @var bool Whether strict-dynamic should be set for 'script-src-elem' */
	protected \$strictDynamicAllowedOnScripts = true;
	/** @var array Domains from which scripts can get loaded */
	protected \$allowedScriptDomains = [
		'\'self\'',
	];
	/**
	 * @var bool Whether inline CSS is allowed
	 * TODO: Disallow per default
	 * @link https://github.com/owncloud/core/issues/13458
	 */
	protected \$inlineStyleAllowed = true;
	/** @var array Domains from which CSS can get loaded */
	protected \$allowedStyleDomains = [
		'\'self\'',
	];
	/** @var array Domains from which images can get loaded */
	protected \$allowedImageDomains = [
		'\'self\'',
		'data:',
		'blob:',
	];
	/** @var array Domains to which connections can be done */
	protected \$allowedConnectDomains = [
		'\'self\'',
	];
	/** @var array Domains from which media elements can be loaded */
	protected \$allowedMediaDomains = [
		'\'self\'',
	];
	/** @var array Domains from which object elements can be loaded */
	protected \$allowedObjectDomains = [];
	/** @var array Domains from which iframes can be loaded */
	protected \$allowedFrameDomains = [
    '$LIQUID_HOST',
];
	/** @var array Domains from which fonts can be loaded */
	protected \$allowedFontDomains = [
		'\'self\'',
		'data:',
	];
	/** @var array Domains from which web-workers and nested browsing content can load elements */
	protected \$allowedChildSrcDomains = [];

	/** @var array Domains which can embed this Nextcloud instance */
	protected \$allowedFrameAncestors = [
		'\'self\'',
	];

	/** @var array Domains from which web-workers can be loaded */
	protected \$allowedWorkerSrcDomains = [];

	/** @var array Domains which can be used as target for forms */
	protected \$allowedFormActionDomains = [
		'\'self\'',
    '$LIQUID_HOST',
	];

	/** @var array Locations to report violations to */
	protected \$reportTo = [];
}
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

run_as "php occ config:system:set allow_local_remote_servers --value 1"

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
