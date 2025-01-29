#!/bin/bash

psql --version
if ( echo "\\d" | psql $XWIKI_DB | grep -q $XWIKI_INIT_CHECK_TABLE ); then
  echo "Table $XWIKI_INIT_CHECK_TABLE was found -- not running init script."
elif [ "$XWIKI_CONFIGURATION" = "false" ]; then
  echo 'Running database initialization script...'
  cat /tmp/xwikidump | psql -v ON_ERROR_STOP=1 --single-transaction $XWIKI_DB
  echo $LIQUID_URL
  psql -c "UPDATE \"xwikidoc\" SET \"xwd_content\" = '* [[Liquid Home>>$LIQUID_URL]]' WHERE \"xwd_content\" LIKE '%LIQUID_URL%';" $XWIKI_DB
  echo 'Successfully ran database initialization script.'
fi

echo "Moving repository from image to correct location."
mkdir -p /usr/local/xwiki/data/extension
mv /tmp/repository /usr/local/xwiki/data/extension

echo "Copy hibernate.cfg.xml config file!"
cat > /usr/local/tomcat/webapps/ROOT/WEB-INF/hibernate.cfg.xml << DELIM
<?xml version="1.0" encoding="UTF-8"?>

<!--
 * See the NOTICE file distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA, or see the FSF site: http://www.fsf.org.
-->

<!DOCTYPE hibernate-configuration PUBLIC
  "-//Hibernate/Hibernate Configuration DTD//EN"
  "http://www.hibernate.org/dtd/hibernate-configuration-3.0.dtd">
<hibernate-configuration>
  <session-factory>

    <!-- Please refer to the installation guide on
         https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/Installation/ for configuring your
         database. You'll need to do 2 things:
         1) Copy your database driver JAR in WEB-INF/lib or in some shared lib directory
         2) Uncomment the properties below for your specific DB (and comment the default
            database configuration if it doesn't match your DB)
    -->

    <!-- Generic parameters common to all Databases -->

    <property name="show_sql">false</property>
    <property name="use_outer_join">true</property>

    <!-- Without it, some queries fail in MS SQL. XWiki doesn't need scrollable result sets, anyway. -->
    <property name="jdbc.use_scrollable_resultset">false</property>

    <!-- DBCP Connection Pooling configuration. Only some properties are shown. All available properties can be found
         at https://commons.apache.org/proper/commons-dbcp/configuration.html
    -->
    <property name="dbcp.defaultAutoCommit">false</property>
    <property name="dbcp.maxTotal">50</property>
    <property name="dbcp.maxIdle">5</property>
    <property name="dbcp.maxWaitMillis">30000</property>
    <property name="connection.provider_class">com.xpn.xwiki.store.DBCPConnectionProvider</property>

    <!-- Setting "dbcp.poolPreparedStatements" to true and "dbcp.maxOpenPreparedStatements" will tell DBCP to cache
         Prepared Statements (it's off by default). Note that for backward compatibility the "dbcp.ps.maxActive" is also
         supported and when set it'll set "dbcp.poolPreparedStatements" to true and "dbcp.maxOpenPreparedStatements" to
         value of "dbcp.ps.maxActive".

         Note 1: When using HSQLDB for example, it's important to NOT cache prepared statements because HSQLDB
         Prepared Statements (PS) contain the schema on which they were initially created and thus when switching
         schema if the same PS is reused it'll execute on the wrong schema! Since HSQLDB does internally cache
         prepared statement there's no performance loss by not caching Prepared Statements at the DBCP level.
         See https://jira.xwiki.org/browse/XWIKI-1740.
         Thus we recommend not turning on this configuration for HSQLDB unless you know what you're doing :)

         Note 2: The same applies to PostGreSQL.
    -->

    <!-- BoneCP Connection Pooling configuration.
    <property name="bonecp.idleMaxAgeInMinutes">240</property>
    <property name="bonecp.idleConnectionTestPeriodInMinutes">60</property>
    <property name="bonecp.partitionCount">3</property>
    <property name="bonecp.acquireIncrement">10</property>
    <property name="bonecp.maxConnectionsPerPartition">60</property>
    <property name="bonecp.minConnectionsPerPartition">20</property>
    <property name="bonecp.statementsCacheSize">50</property>
    <property name="bonecp.releaseHelperThreads">3</property>
    <property name="connection.provider_class">com.xpn.xwiki.store.DBCPConnectionProvider</property>
    -->


<!-- PostgreSQL configuration.
         Notes:
           - "jdbc.use_streams_for_binary" needs to be set to "false",
             see https://community.jboss.org/wiki/HibernateCoreMigrationGuide36
           - "xwiki.virtual_mode" can be set to either "schema" or "database". Note that currently the database mode
             doesn't support database creation (see https://jira.xwiki.org/browse/XWIKI-8753)
           - if you want the main wiki database to be different than "xwiki" (or "public" in schema mode)
             you will also have to set the property xwiki.db in xwiki.cfg file
    -->
    <property name="connection.url">jdbc:postgresql://$XWIKI_DB_URL/xwiki</property>
    <property name="connection.username">xwiki</property>
    <property name="connection.password">$DB_PASSWORD</property>
    <property name="connection.driver_class">org.postgresql.Driver</property>
    <property name="jdbc.use_streams_for_binary">false</property>
    <property name="xwiki.virtual_mode">schema</property>

    <property name="hibernate.connection.charSet">UTF-8</property>
    <property name="hibernate.connection.useUnicode">true</property>
    <property name="hibernate.connection.characterEncoding">utf8</property>

    <mapping resource="xwiki.postgresql.hbm.xml"/>
    <mapping resource="feeds.hbm.xml"/>
    <mapping resource="instance.hbm.xml"/>
    <mapping resource="notification-filter-preferences.hbm.xml"/>
    <mapping resource="mailsender.hbm.xml"/>
  </session-factory>
</hibernate-configuration>
DELIM

echo "Copy xwiki.cfg config file!"
cat > /usr/local/tomcat/webapps/ROOT/WEB-INF/xwiki.cfg << DELIM
# ---------------------------------------------------------------------------
# See the NOTICE file distributed with this work for additional
# information regarding copyright ownership.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.
# ---------------------------------------------------------------------------

#---------------------------------------
# Preamble
#
# This is the main old XWiki configuration file. Commented parameters show the default value, although some features
# might be disabled. To customize, uncomment and put your own value instead.
# 
# This file come from one of those locations (in this order):
# * [since 9.3] /etc/xwiki/xwiki.cfg
# * /WEB-INF/xwiki.cfg in the web application resources

#---------------------------------------
# General wiki settings
#

#-# When the wiki is readonly, any updates are forbidden. To mark readonly, use one of: yes, 1, true
# xwiki.readonly=no

#-# [Since 1.6RC1] The list of supported syntaxes is defined as an xobject in the Rendering.RenderingConfig page
#-# and you can change it using the Admin UI of XWiki. When the Rendering.RenderingConfig page doesn't exist, the list
#-# of supported syntaxes is taken from this property. And if there's no syntax listed, then the default syntax is
#-# supported by defaut (this default syntax is defined in xwiki.properties using the core.defaultDocumentSyntax
#-# property).
#-# Example of syntaxes:
#-#    xwiki/2.0, xwiki/2.1, confluence/1.0, jspwiki/1.0, creole/1.0,  mediawiki/1.0, twiki/1.0, xhtml/1.0,
#-#    html/4.01, plain/1.0, docbook/4.4, markdown/1.0, markdown/1.1, apt/1.0
#-# xwiki.rendering.syntaxes = xwiki/2.1

#-# List of groups that a new user should be added to by default after registering. Comma-separated list of group
#-# document names.
#-# The default list depends on the value of xwiki.authentication.group.allgroupimplicit:
#-# 0: created users are added to XWiki.XWikiAllGroup group page
#-# 1: created users are not added to any group page (but they will virtually be part of XWiki.XWikiAllGroup group)
# xwiki.users.initialGroups=XWiki.XWikiAllGroup

#-# Should all users be considered members of XWiki.XWikiAllGroup, even if they don't have an associated object in the
#-# group's document?
#-# 0: XWiki.XWikiAllGroup behaves like any other group and, by default, new users are added to it (you can change that using xwiki.users.initialGroups)
#-# 1: All users are considered members of the XWiki.XWikiAllGroup group no matter what it actually contains
#-# The default is 0.
# xwiki.authentication.group.allgroupimplicit=0

#-# Uncomment if you want to ignore requests for unmapped actions, and simply display the document
# xwiki.unknownActionResponse=view

#-# The encoding to use when transformin strings to and from byte arrays. This causes the jvm encoding to be ignored,
#-# since we want to be independend of the underlying system.
xwiki.encoding=UTF-8

#-# This parameter will activate the sectional editing.
xwiki.section.edit=1

#-# This parameter controls the depth of sections that have section editing.
#-# By default level 1 and level 2 sections have section editing.
xwiki.section.depth=2

#-# Enable backlinks storage, which increases the update time, but allows to keep track of inter document links.
xwiki.backlinks=1

#-# Enable document tags.
xwiki.tags=1

#-# [Since 6.1M1] HTTP cache settings: by default, HTTP responses generated by XWiki actions are not supposed to be cached,
#-# since they often contain dynamic content. This can be controlled globally using the following setting, with accepted values:
#-# - 0: no Cache-Control header sent, use the browser's defaults. RFC 2616 only specifies optional behavior in this case
#-# - 1: no-cache; caches must not serve this response in a subsequent response, but the page is stored for the bf-cache
#-# - 2: no-store, no-cache and max-age=0; the response will never be reused, not even for bf-cache; note that unsaved changes may be lost
#-# - 3: private; the response will be cached by personal caches, such as a browser cache
#-# - 4: public; the response may be cached by both personal and shared caches
#-# This can be overridden in each wiki using a headers_nocache XWikiPreferences property of type Long.
# xwiki.httpheaders.cache=1

#---------------------------------------
# Storage
#

#-# Role hints that differentiate implementations of the various storage components. To add a new implementation for
#-# one of the storages, implement the appropriate interface and declare it in a components.xml file (using a role-hint
#-# other than 'default') and put its hint here.

#-# Stores with both "hibernate" and "file" support in XWiki Standard.
#-# [Since 10.5RC1] The default is "file" for all of them.
#-# 
#-# [Since 9.0RC1] The default document content recycle bin storage.
#-# This property is only taken into account when deleting a document and has no effect on already deleted documents.
# xwiki.store.recyclebin.content.hint=file
#-# The attachment content storage.
# xwiki.store.attachment.hint=file
#-# The attachment versioning storage. Use 'void' to disable attachment versioning.
# xwiki.store.attachment.versioning.hint=file
#-# [Since 9.9RC1] The default attachment content recycle bin storage.
#-# This property is only taken into account when deleting an attachment and has no effect on already deleted documents.
# xwiki.store.attachment.recyclebin.content.hint=file

#-# Stores with only "hibernate" support in XWiki Standard
#-# 
#-# The main (documents) storage.
# xwiki.store.main.hint=hibernate
#-# The document versioning storage.
# xwiki.store.versioning.hint=hibernate
#-# The document recycle bin metadata storage.
# xwiki.store.recyclebin.hint=hibernate
#-# The attachment recycle bin metadata storage.
# xwiki.store.attachment.recyclebin.hint=hibernate
#-# The Migration manager.
# xwiki.store.migration.manager.hint=hibernate

#-# Whether the document recycle bin feature is activated or not
# xwiki.recyclebin=1
#-# Whether the attachment recycle bin feature is activated or not
# storage.attachment.recyclebin=1
#-# Whether the document versioning feature is activated or not
# xwiki.store.versioning=1
#-# Whether the attachment versioning feature is activated or not
# xwiki.store.attachment.versioning=1
#-# Whether the attachments should also be rolled back when a document is reverted.
# xwiki.store.rollbackattachmentwithdocuments=1

#-# The path to the hibernate configuration file.
# xwiki.store.hibernate.path=/WEB-INF/hibernate.cfg.xml

#-# Allow or disable custom mapping for particular XClasses. Custom mapping may increase the performance of certain
#-# queries when large number of objects from particular classes are used in the wiki.
# xwiki.store.hibernate.custommapping=1
#-# Dynamic custom mapping.
# xwiki.store.hibernate.custommapping.dynamic=0

#-# Put a cache in front of the document store. This greatly improves performance at the cost of memory consumption.
#-# Disable only when memory is critical.
# xwiki.store.cache=1

#-# Maximum number of documents to keep in the cache.
#-# The default is 500.
# xwiki.store.cache.capacity=500

#-# Maximum number of documents to keep in the cache indicating if a document exist.
#-# Since this cache contain only boolean it can be very big without taking much memory.
#-# The default is 10000.
# xwiki.store.cache.pageexistcapacity=10000

#-# [Since 1.6M1]
#-# Force the database name for the main wiki.
# xwiki.db=xwiki

#-# [Since 1.6M1]
#-# Add a prefix to all databases names of each wiki.
# xwiki.db.prefix=


#---------------------------------------
# Data migrations and schema updates
#
# [Since 3.3M1] Migration and schema updates are now done together. Data migration manipulates the actual data,
# and schema updates change the layout of the database. Schema updates are require for proper database access
# and migration are useful for migrating data to new formats, correct errors introduced in older versions, or
# even for schema updates which are not backward compatible.

#-# Whether schema updates and migrations are enabled or not. Should be enabled when upgrading, but for a better
#-# startup time it is better to disable them in production.
xwiki.store.migration=1

#-# Whether to exit after migration. Useful when a server should handle migrations for a large database, without going
#-# live afterwards.
# xwiki.store.migration.exitAfterEnd=0

#-# Indicate the list of databases to migrate.
#-# to upgrade all wikis database set xwiki.store.migration.databases=all
#-# to upgrade just some wikis databases set xwiki.store.migration.databases=xwiki,wiki1,wiki2
#-# Note: the main wiki is always migrated whatever the configuration.
#-# [Since 3.3M1] default to migrate all databases
# xwiki.store.migration.databases=all

#---------------------------------------
# Internationalization
#

#-# By default, XWiki chooses the language specified by the client (browser) in the Accept-Language HTTP header. This
#-# allows to use the default language of the wiki when the user didn't manually choose a language.
# xwiki.language.preferDefault=0

#-# Force only one of the supported languages to be accepted. Default to true.
# xwiki.language.forceSupported=1


#---------------------------------------
# Virtual wikis (farm)
#

#-# Starting with XWiki 5.0M2, virtual mode is enabled by default.

#-# [Since 5.0M2]
#-# What to do when the requested wiki does not exist:
#-# - 0: (default) serve the main wiki
#-# - 1: display an error (customizable through wikidoesnotexist.vm or xwiki:XWiki.WikiDoesNotExist)
# xwiki.virtual.failOnWikiDoesNotExist=0

#-# Forbidden names that should not be allowed when creating a new wiki.
# xwiki.virtual.reserved_wikis=

#-# How virtual wikis are mapped to different URLs.
#-# If set to 0, then virtual wikis have different domain names, in the format http://wikiname.myfarm.net/.
#-# If set to 1 (the default), then the domain is common for the entire farm, but the path contains the wiki name,
#-# in the format http://myfarm.net/xwiki/wiki/wikiname/.
#-# Note that you can configure the "/wiki/" part with xwiki.virtual.usepath.servletpath property.
# xwiki.virtual.usepath=1

#-# Configure the servlet action identifier for url path based multiwiki. It has also to be modified in web.xml.
# xwiki.virtual.usepath.servletpath=wiki

#---------------------------------------
# URLs
#

#-# The domain name to use when creating URLs to the default wiki. If set, the generated URLs will point to this server
#-# instead of the requested one. It should contain schema, domain and (optional) port, and the trailing /. For example:
#-# xwiki.home=http://www.xwiki.org/
#-# xwiki.home=http://wiki.mycompany.net:8080/
# xwiki.home=

#-# The name of the default URL factory that should be used.
# xwiki.urlfactory.serviceclass=com.xpn.xwiki.web.XWikiURLFactoryServiceImpl

#-# The default protocol to use when generating an external URL. Can be overwritten in the wiki descriptor ("secure" property).
#-# If not set, the following is used:
#-#   * during client request for the current wiki: the protocol from the URL used by the client
#-#   * for a different wiki or during background tasks (mails, etc.): information come from the wiki descriptor (also fallback on main wiki)
#-# For example:
#-# xwiki.url.protocol=https
# xwiki.url.protocol=
#-# The name of the webapp to use in the generated URLs. If not specified, the value is extracted from the request URL
#-# and thus it's generally not required to set it. However if you're deploying XWiki as ROOT in your Servlet Container
#-# and you're using XWiki 6.2.8+/6.4.3+/7.0+ you must set it to an empty value as otherwise the code cannot guess it.
#-# Note that not setting this property seemed to work on previous versions when deploying as ROOT but it was actually
#-# leading to errors from time to time, depending on what URL was used when doing the first request on the XWiki
#-# instance.
#-# For example:
#-xwiki.webapppath=
xwiki.webapppath=
#-# The default servlet mapping name to use in the generated URLs. The right value is taken from the request URL,
#-# preserving the requested servlet mapping, so setting this is not recommended in most cases. If set, the value should
#-# contain a trailing /, but not a leading one. For example:
#-# xwiki.servletpath=bin/
# xwiki.servletpath=
#-# The fallback servlet mapping name to use in the generated URLs. Unlike xwiki.servletpath, this is the value used
#-# when the correct setting could not be determined from the request URL. A good way to use this setting is to achieve
#-# short URLs, see https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/ShortURLs/
# xwiki.defaultservletpath=bin/

#-# Whether the /view/ part of the URL should be included if the target action is 'view'.
# xwiki.showviewaction=1
#-# The name of the default space. This is displayed when the URL specifies a document, but not a space, or neither.
# xwiki.defaultweb=Main
#-# The name of the default page of a space. This is displayed when the URL specifies a space, but not a document, or
#-# neither.
# xwiki.defaultpage=WebHome
#-# Hide the /WebHome part of the URL when the document is the default one. Use 0 to hide, 1 to show.
# xwiki.usedefaultaction=0

#-# [Since 4.0RC1]
#-# Indicate if the URL used in HTTPSevlet#sendRedirect should be made absolute by XWiki or left to application server.
#-# Sending absolute URLs is a bad practice and generally not needed. This option is mostly here as retro-compatibility
#-# switch and you should always make sure to properly configure your application server or any proxy behind it before
#-# using this.
#-# 0: send relative URLs (the default)
#-# 1: send absolute URLs
# xwiki.redirect.absoluteurl=0

#---------------------------------------
# Users
#

xwiki.inactiveuser.allowedpages=


#---------------------------------------
# Authentication and authorization
#

#-# Enable to allow superadmin. It is disabled by default as this could be a
#-# security breach if it were set and you forgot about it. Should only be enabled
#-# for recovering the Wiki when the rights are completely messed.
xwiki.superadminpassword=$SUPERADMIN_PASSWORD

#-# Authentication type. You can use 'basic' to always use basic authentication.
# xwiki.authentication=form

#-# Indicate if the authentication has do be done for each request
#-# 0: the default value, authentication is done only once by session.
#-# 1: the authentication is done for each request.
# xwiki.authentication.always=0

#-# Cookie encryption keys. They are randomly generated and stored when not specified.
# xwiki.authentication.validationKey=totototototototototototototototo
# xwiki.authentication.encryptionKey=titititititititititititititititi

#-# Comma separated list of domains for which authentication cookies are set. This
#-# concerns mostly wiki farms. The exact meaning is that when a user logs in, if
#-# the current domain name corresponding to the wiki ends with one of the entries
#-# in this parameter, then the cookie is set for the larger domain. Otherwise, it
#-# is set for the exact domain name of the wiki.
#-#
#-# For example, suppose the cookiedomains is set to "mydomain.net". If I log in
#-# on wiki1.xwiki.com, then the cookie will be set for the entire mydomain.net
#-# domain, and if I visit wiki2.xwiki.com I will still be authenticated. If I log
#-# in on wiki1.otherdomain.net, then I will only be authenticated on
#-# wiki1.otherdomain.net, and not on wiki2.otherdomain.net.
#-#
#-# So you need this parameter set only for global authentication in a
#-# farm, there's no need to specify your domain name otherwise.
#-#
#-# Example: xwiki.authentication.cookiedomains=xwiki.org,myxwiki.org
xwiki.authentication.cookiedomains=
xwiki.authentication.cookielife=$XWIKI_COOKIE_LIFETIME

#-# This allows logout to happen for any page going through the /logout/ action, regardless of the document or the
#-# servlet.
#-# Comment-out if you want to enable logout only for /bin/logout/XWiki/XWikiLogout
#-# Currently accepted patterns:
#-# - /StrutsServletName/logout/ (this is usually /bin/logout/ and is the default setup)
#-# - /logout/ (this works with the short URLs configuration)
#-# - /wiki/SomeWikiName/logout/ (this works with path-based virtual wikis)
xwiki.authentication.logoutpage=(/|/[^/]+/|/wiki/[^/]+/)logout/*

#-# The group management class.
# xwiki.authentication.groupclass=com.xpn.xwiki.user.impl.xwiki.XWikiGroupServiceImpl

#-# The authentication management class.
xwiki.authentication.authclass=org.xwiki.contrib.oidc.auth.OIDCAuthServiceImpl

#-# (Deprecated) The authorization management class.
#-# [Since 5.0M2] The default right service is now org.xwiki.security.authorization.internal.XWikiCachingRightService
#-# which is a bridge to the new security authorization component. It provides increased security and performance, but
#-# its right policies differ sightly from the old Right Service implementation. In rare situation, you may want to
#-# switch back to the old unmaintained implementation by uncommenting the following line. However, only old
#-# implementation, still using a bridged RightService will be impacted by this parameter. Customization of the new
#-# security authorization component should be done in the new xwiki.properties configuration (security.*).
# xwiki.authentication.rightsclass=com.xpn.xwiki.user.impl.xwiki.XWikiRightServiceImpl

#-# If an unauthenticated user (guest) tries to perform a restricted action, by default the wiki redirects to the login
#-# page. Enable this to simply display an "unauthorized" message instead, to hide the login form.
# xwiki.hidelogin=false

#-# Used by some authenticators (like com.xpn.xwiki.user.impl.xwiki.AppServerTrustedAuthServiceImpl)
#-# to indicate that the users should be created. In this kind of authenticator the user are not created by default.
#-# Must be set to "empty".
# xwiki.authentication.createuser=empty

#-# If set to true(the default value), cookies of users are blocked from being used except by the same IP address 
#-# which got them.  
# xwiki.authentication.useip=true

#---------------------------------------
# Editing
#

#-# Minor edits don't participate in notifications.
# xwiki.minoredit=1

#-# Use edit comments
xwiki.editcomment=1

#-# Hide editcomment field and only use Javascript
# xwiki.editcomment.hidden=0

#-# Make edit comment mandatory
xwiki.editcomment.mandatory=0

#-# Make edit comment suggested (asks 1 time if the comment is empty.
#-# 1 shows one popup if comment is empty.
#-# 0 means there is no popup.
#-# This setting is ignored if mandatory is set
# xwiki.editcomment.suggested=0

#---------------------------------------
# Skins & Templates configuration
#

#-# The default skin to use when there's no value specified in the wiki preferences document. Note that the default
#-# wiki already specifies a skin, so this setting is only valid for empty wikis.
xwiki.defaultskin=flamingo

#-# The default base for skins that don't specify a base skin. This is also the last place where a skin file is searched
#-# if not found in the more specific skins.
xwiki.defaultbaseskin=flamingo

#-# Defines whether title handling should be using the compatibility mode or not. When the compatibility
#-# mode is active, XWiki will try to extract a title from the document content.
#-# If the document's content first header (level 1 or level 2) matches the document's title
#-# the first header is stripped.
#-# The default value is 0.
# xwiki.title.compatibility=1

#-# Defines the maximum header depth to look for when computing a document's title from its content. If no header
#-# equal or lower to the specified depth is found then the computed title falls back to the document name.
#-# The default value is 2.
# xwiki.title.headerdepth=2

#-# Defines if setting the title field must be mandatory in the WYSIWYG and Wiki editors. It is mandatory when this
#-# property is set to 1. The default value is 0 (not mandatory).
# xwiki.title.mandatory=0

#---------------------------------------
# Plugin Mechanism
#

#-# List of active plugins.
xwiki.plugins=\
  com.xpn.xwiki.monitor.api.MonitorPlugin,\
  com.xpn.xwiki.plugin.skinx.JsSkinExtensionPlugin,\
  com.xpn.xwiki.plugin.skinx.JsSkinFileExtensionPlugin,\
  com.xpn.xwiki.plugin.skinx.JsResourceSkinExtensionPlugin,\
  com.xpn.xwiki.plugin.skinx.CssSkinExtensionPlugin,\
  com.xpn.xwiki.plugin.skinx.CssSkinFileExtensionPlugin,\
  com.xpn.xwiki.plugin.skinx.CssResourceSkinExtensionPlugin,\
  com.xpn.xwiki.plugin.skinx.LinkExtensionPlugin,\
  com.xpn.xwiki.plugin.feed.FeedPlugin,\
  com.xpn.xwiki.plugin.mail.MailPlugin,\
  com.xpn.xwiki.plugin.packaging.PackagePlugin,\
  com.xpn.xwiki.plugin.fileupload.FileUploadPlugin,\
  com.xpn.xwiki.plugin.image.ImagePlugin,\
  com.xpn.xwiki.plugin.rightsmanager.RightsManagerPlugin,\
  com.xpn.xwiki.plugin.jodatime.JodaTimePlugin,\
  com.xpn.xwiki.plugin.scheduler.SchedulerPlugin,\
  com.xpn.xwiki.plugin.mailsender.MailSenderPlugin,\
  com.xpn.xwiki.plugin.tag.TagPlugin,\
  com.xpn.xwiki.plugin.zipexplorer.ZipExplorerPlugin

#---------------------------------------
# Monitor Plugin
#

#-# Enable light monitoring of the wiki performance. Records various statistics, like number of requests processed,
#-# time spent in rendering or in the database, medium time for a request, etc. Disable for a minor increase of
#-# performance and a bit of memory.
# xwiki.monitor=1

#-# Maximum number of last requests to remember.
# xwiki.monitor.lastlistsize=20

#---------------------------------------
# Image Plugin
#

xwiki.plugin.image.cache.capacity=30

#---------------------------------------
# Watchlist Plugin
#

#-# [Since 3.1M1]
#-# Indicate which mode to use for automatic document watching.
#-# The possibles modes are the following:
#-# * none: never automatically add document in watchlist
#-# * all: add to watchlist any modified document
#-# * major: add to watchlist only document which are not edited as minor edit. That's the default mode.
#-# * new: add to watchlist only newly created documents
# xwiki.plugin.watchlist.automaticwatch=major

#---------------------------------------
# Statistics Plugin
#

#-# Note that this plugin is in charge of storing stats in the database, and offering some API to query them.
#-# It doesn't provide any UI. If you wish to install a UI, please check the Statistics Application at
#-# https://extensions.xwiki.org/xwiki/bin/view/Extension/Statistics+Application
#-# (this application is no longer bundled in XWiki starting with 8.0)

#-# Stats configuration allows to globally activate/deactivate stats module (launch storage thread, register events...).
#-# Enabled by default.
# xwiki.stats=1
#-# When statistics are globally enabled, storage can be enabled/disabled by wiki using the XWikiPreference property
#-# "statistics".
#-# Note: Statistics are disabled by default for improved performances/space.
xwiki.stats.default=0

#-# Deprecated since 2.5M1. Use "xwiki.stats.request.excludedUsersAndGroups" instead.
# xwiki.stats.excludedUsersAndGroups=XWiki.Admin,XWiki.XWikiGuest

#-# [Since 2.5M1]
#-# List of users and groups to filter from the visit search request result. Entities are comma separated and can be
#-# relative.
#-# "XWiki.Admin" means "XWiki.Admin" user on the wiki where the search is done and "xwiki:XWiki.Admin" only filter
#-# admin user from main wiki.
#-# For example, the following filter default admin user and unregistered user from the most active contributor graph
#-# on Stats.WebHome page:
# xwiki.stats.request.excludedUsersAndGroups

#-# [Since 2.5M1]
#-# List of users and groups to skip when storing statistics to the database. Entities are comma separated and can be
#-# relative.
#-# "XWiki.Admin" means "XWiki.Admin" user on the wiki where the search is done and "xwiki:XWiki.Admin" only filter
#-# admin user from main wiki.
#-# For example, the following filter avoid storing statistics for the user "HiddenUser":
# xwiki.stats.excludedUsersAndGroups=XWiki.HiddenUser

#-# It is also possible to choose a different stats service to record statistics separately from XWiki.
# xwiki.stats.class=com.xpn.xwiki.stats.impl.XWikiStatsServiceImpl

#---------------------------------------
# Import/Export
#

#-# [Since 6.2]
#-# Indicate if Filter module should be used when exporting a XAR in the export action.
#-# By default Filter module is used, uncomment to use the old system.
# xwiki.action.export.xar.usefilter=0

#-# [Since 12.0]
#-# Indicate if the XAR packages should be optimized (from size point of view) by default.
#-# Can be overwritten with URL parameter "?optimized=false".
#-# The default is:
# xwiki.action.export.xar.optimized=1
#-# [Since 12.0]
#-# Indicate if the JRCS format should be used for attachment history in XAR packages by default.
#-# Enabled by default for retro compatibility reasons.
#-# Can be overwritten with URL parameter "?attachment_jrcs=false"
#-# The default is:
# xwiki.action.export.xar.attachment.jrcs=1
DELIM


cat >> /usr/local/tomcat/webapps/ROOT/WEB-INF/xwiki.properties << DELIM
oidc.endpoint.authorization=$OAUTH2_AUTHORIZE_URL
oidc.endpoint.token=$OAUTH2_TOKEN_URL
oidc.endpoint.userinfo=$OAUTH2_PROFILE_URL
oidc.scope=openid,profile,email,read,write
oidc.endpoint.userinfo.method=GET
oidc.user.nameFormater={% raw %}\${oidc.user.id._clean._lowerCase}{% endraw %}
oidc.user.subjectFormater={% raw %}\${oidc.user.id}{% endraw %}
oidc.groups.claim=$OAUTH2_GROUPS_CLAIM
oidc.groups.mapping=XWikiAdminGroup=admin
# oidc.groups.mapping=MyXWikiGroup2=my-oidc-group2
# oidc.groups.mapping=MyXWikiGroup2=my-oidc-group3
# oidc.groups.allowed=
# oidc.groups.forbidden=
oidc.userinfoclaims=xwiki_user_accessibility,xwiki_user_company,xwiki_user_displayHiddenDocuments,xwiki_user_editor,xwiki_user_usertype
# oidc.userinforefreshrate=600000
oidc.clientid=$OAUTH2_CLIENT_ID
oidc.secret=$OAUTH2_CLIENT_SECRET
oidc.endpoint.token.auth_method=client_secret_post
oidc.skipped=false

distribution.defaultUI=org.xwiki.platform:xwiki-platform-distribution-flavor-mainwiki
distribution.defaultWikiUI=org.xwiki.platform:xwiki-platform-distribution-flavor-wiki
distribution.job.interactive=false
distribution.job.interactive.wiki=false
DELIM

echo "Starting original entrypoint!"

# Start Nginx in the foreground
nginx -g "daemon off;" &

exec /usr/local/bin/docker-entrypoint.sh xwiki
