# Liquid Investigations Change Log

## Unreleased


---


## v0.24.9 (2023-05-09)

### New Features
- New App: Integrated new Wiki app, Wiki.js. This system has modern features,
  such as visual editing, role-based access control, and comments.

### Bug Fixes
- Hoover: Fixed bug where, on some collections, document pages would
  intermittently raise errors when fetching the location list.
- Hoover: Fixed bug where Translate would fail on documents where OCR was
  enabled but not executed.

---

## v0.24.1 (2023-03-03)

### Improvements
- Nextcloud: Added second Nextcloud instance, with different permission flags, that admins may enable. See [configuration section](https://github.com/liquidinvestigations/node/blob/b658626ddc1ef9ebf55b429ce00619426324a6a0/examples/liquid.ini#L407-L408C15)

### Bug Fixes
- Deployment: Fixed bug where the `./liquid deploy` command would download more images than necessary.

---

## v0.23.14 (2023-02-22)

### Bug Fixes
- Dokuwiki: Fix issue where Sitemap would not expand entries for users with restricted access.
- Hoover: Fixed "File Finder" issue where the root folder would be displayed as a different file.
- Hoover: Fixed bug causing wrong collection display in the Batch Search view.

## v0.23.13 (2023-02-21)

### Improvements
- Dokuwiki: Limited expansion of new Sitemap entries to one level.

## v0.23.12 (2023-02-17)

### Improvements
- Dokuwiki: Added ability to create custom Sitemaps for user-made namespaces, and place them in any page.

### Bug Fixes
- Dokuwiki: Fixed bug where Sitemap would not display private wiki content allowed from ACL / Virtual Manager.

## v0.23.9 (2023-02-10)

### Bug Fixes
- Hoover: fixed bug causing delay while indexing new data in the uploads (NextCloud) collection.

---

## v0.23.8 (2023-01-31)

### Improvements
- Sysadmin: added new tracing system at port 9975, with Hoover-specific performance metrics and charts.
- Hoover: better processing performance on large collections.

### Bug Fixes
- Hoover: fixed bug causing excessive disk space usage from system logs.

---

## v0.22.0 (2023-01-13)

### Improvements
- Hoover: the collection configuration for very expensive operations (entity
  extraction, translation, image classification, image detection) must now be
  explicitly enabled for every collection.

### Bug Fixes
- Hoover: Fixed worker slowdown issue for old containers by adding restart timeout of 3-5 days for all hoover data workers.

---

## v0.21.2 (2022-12-21)

### Improvements
- Dokuwiki: Added Virtual Group Plugin, which allows Access Control for all
  Wiki Instances. Both Group Management and Access Control are managed from the
  Dokuwiki Admin Page.
- Hoover: Added new configuration flag `snoop_unarchive_threads` for parallel
  unpacking of BZ2 type archives. BZ2 archives will now be unpacked with
  greater speed. Any other archive types (zip, rar) are not affected.

### Bug Fixes
- Hoover: Fixed issue where Tika Temporary Files folder would grow unbounded in
  size, using up all available disk space on the `/` partition. The workaround
  without this fix is to simply "stop" the Tika containers from Nomad UI every
  time this happens. The data has been moved to the Nomad data folder, by
  default `/opt/cluster/var/nomad/alloc/...`. Additionally, the Temporary
  folder has been set-up to auto-delete files older than a few days.

---
## v0.21.1 (2022-11-23)

### Improvements
- Hoover: Batch Search now has an internal queue to support very long batch search queries, and a large number of users searching in parallel.

### Bug Fixes
- Hoover: Fixed Batch Search function issue where the search would error out with "Bad Request" on large lists.


---
## v0.21.0 (2022-11-18)

### Bug Fixes
- Removed 7z-fuse archive mounting feature. This migration will remove the feature from all collections, and resets the unarchive tasks needed to re-create the archived files.


---
## v0.20.3 (2022-10-25)

### New Features
- Admin: Home page optionally proxies dashboards for Grafana, Nomad, Snoop, as well as search and processing queues. Only available to Admins with SuperUser access permission. To enable, [set `[liquid] enable_superuser_dashboards = true`](https://github.com/liquidinvestigations/node/blob/master/examples/liquid.ini#L172-L174) in `liquid.ini`.

### Bug Fixes
- Fixed bug with archive mounting, where large amounts of storage would be used by logs. Disabled the archive mounting feature by default. Added warnings to switch off configuration related to archive mounting.
- Fixed bug where long searches would sometimes fail to show aggregations.
- Initiated reprocessing of email-related tasks, to resolve the "Invalid DateTime" bug. To upgrade, set `process = True` on all collections.
- Fixed bug where processing queue memory would become full, and processing would completely halt. A larger number of collections can now be processed at the same time with `process = True`.


---
# v0.20.1 (2022-08-26)

### Bug Fixes
- Fixed Hoover bug where OCR processing would sometimes fail.
- Fixed Hoover bug where some files would produce errors if they had an unusual Russian encoding.


---
# v0.20.0 (2022-08-17)

### New Features
- Hoover script for batch importing of tags from a CSV file.
- Hoover script for checking for data loss and deleting orphaned objects.

### Improvements
- Admin: feature 'delete users' also deletes them in all apps.

### Bug Fixes
- Fixed UI bug that would display an error when searches take more than one minute.
- Fixed ephemeral bug that would leak storage space when PDF previews are used with 2 or more OCR langauges.
- Fixed related to recursive archive mounts.
- Fixed homepage service deployment problem, saved 30 seconds.


---
## v0.19.14 (2022-07-21)

### Improvements
- Hoover: Backup procedure now includes arguments to optionally backup and restore original collection data. Also, original collection data backup has been enabled for "uploads" in the `bin/periodic-backup.sh` script.

### Bug Fixes
- Hoover: Fixed processing of some variants of `application/mbox` MBox Email Archives which would previously fail to unpack.
- Hoover: Removed mismatching OCR tabs from documents where a language was detected and OCR is available for it.
- Hoover: Removed Translations made from one target language into another one.
- Authentication: Fixed bug where user sessions would be lost after server redeployment.


---
## v0.19.13 (2022-07-11)

### Bug Fixes
- Fixed Hoover bug that would stop new Tags from being indexed.


---
## v0.19.12 (2022-07-06)

### Bug Fixes
- Fixed issue where synced collections (such as "uploads") would not update the index.
- Fixed performance problem caused by recursive archive mounts.


---
## v0.19.11 (2022-06-30)

This version fixes bugs in Rocketchat and Hoover configuration.

### Bug Fixes
- Fixed Rocketchat issue where new servers would fail to start.
- Fixed Hoover processing stability issue caused by 7z mount process leak.
- Fixed bug with Hoover `retrytasks` command and UI button.

---
## v0.19.8 (2022-06-24)

### Bug Fixes
- Fixed issue where Hoover indexing would hang on very large collections.
- Fixed S3 mount process leak, which could crash systems under a few days of load.


### Improvements
- Hoover: Improve processing performance by re-using network mounts.
- Hoover: Collection data archive mounting can be disabled, and normal unpacking will be used instead. Config flag: `disable_archive_mounting`.

---
## v0.19.7 (2022-06-17)

This release brings performance improvements for the Hoover processing pipeline.

### Upgrade Notes
- Follow ["clean reset" procedure](https://github.com/liquidinvestigations/docs/wiki/Maintenance#clean-reset) with **[cluster version 0.15.3](https://github.com/liquidinvestigations/cluster/tree/v0.15.3)**

### Improvements
- Hoover: Added configuration for OCR parallelism: [configuration](https://github.com/liquidinvestigations/node/blob/1f7ac656076530543d5a0cbce85da49fbdc9463f/examples/liquid.ini#L248-L253).
- Hoover: Added configuration for describing files to be skipped from processing: [configuration](https://github.com/liquidinvestigations/node/blob/1f7ac656076530543d5a0cbce85da49fbdc9463f/examples/liquid.ini#L245-L247).

### Bug Fixes
- Fixed problem where Hoover processing pipeline would cause server to run out of memory.
- Fixed performance issue where processing would run much slower than normal.


---
## v0.19.2 (2022-06-09)

This is a bug-fixing release targeted at Hoover internals and Monitoring.

### Upgrade Notes

- Follow ["clean reset" procedure](https://github.com/liquidinvestigations/docs/wiki/Maintenance#clean-reset) with **[cluster version 0.15.0](https://github.com/liquidinvestigations/cluster/tree/v0.15.0)**


### Bug Fixes
- Hoover: Fixed issue where mail fields wouldn't appear (From, To, text) for some mail formats.
- Monitoring: Fixed issue with monitoring apps not working (Grafana, Prometheus).
- Scheduling: Fixed bug where dead and de-activated nodes would be counted as valid in the resource checker.


---
## v0.19.1 (2022-06-07)

This bugfixing version brings stability improvements for multi-host deployments.

### Upgrade Notes
- Follow ["clean reset" procedure](https://github.com/liquidinvestigations/docs/wiki/Maintenance#clean-reset) with **[cluster version 0.14.2](https://github.com/liquidinvestigations/cluster/tree/v0.14.2)**

### Improvements
- Hoover: Skip Windows and Linux installation files and extensions by default. Added new configuration flags to control what file types and extensionis are skipped.

### Bug Fixes
- Hoover: Fixed issue when optional processes (OCR, NLP and Image Recognition, etc) would be turned on and then off again on an active collection.


---
## v0.19.0 (2022-05-17)

**Hypothesis is removed** from the project starting with this version.
### Upgrade Notes
- Follow ["clean reset" procedure](https://github.com/liquidinvestigations/docs/wiki/Maintenance#clean-reset) with **[cluster version 0.13.7](https://github.com/liquidinvestigations/cluster/tree/v0.13.7)**

### New Features
- Hoover now recognizes tables (CSV, Excel, ODT) and splits them into smaller parts that can be viewed in the UI.

### Improvements
- Hoover: Run OCR analyzer on Office type documents (doc, docx, odt). Previously, OCR would only run on PDF files only.
- Hoover: Improved performance of whole-document OCR with existing text.
- Hoover: Collection Access Management now implemented for Admins too. Admins can't give access to collections they're not a part of.

### Bug Fixes
- Hoover: Fixed ETA display for document processing.
- Fixed problem where some user sessions would still be active after user logout.
- Hoover: Fix performance issue related to document processing.
- Hoover: Fixed bug where collections couldn't be deleted if they had a certain name.
- Hoover: Fixed bug where Entity Extraction wouldn't work on some languages (Japanese, Russian, Arabic).


---
## v0.18.2 (2022-04-29)

### Upgrade Notes
- For very large installations expect a few hours of downtime during release.
- Follow ["clean reset" procedure](https://github.com/liquidinvestigations/docs/wiki/Maintenance#clean-reset) with **[cluster version 0.13.6](https://github.com/liquidinvestigations/cluster/tree/v0.13.6)**
- New restriction for **collection names: at least 3 characters** in length.
  Before upgrading, please backup the offending collections and restore them
  with names longer than 2 characters.
- **Make sure the `/` filesystem has at least `120 GB`** for new Docker images,
  or bind mount `/var/lib/docker` to a place with more space.
- When updating, the service `hoover-snoop` will run migrations that may take a few hours. 
  Because of that, do not restart the `./liquid deploy` command before checking that migrations
  are finished in the Nomad UI, at `Jobs > hoover > snoop-web > snoop`.


### New Features

- Hoover: Image AI: Image Classification and Object Recognition. Filter images
  by the objects detected inside by AI models we download and run.
  [Configuration for Image Classification and Object Recognition](https://github.com/liquidinvestigations/node/blob/5ac3114bcedb8899e8326e332dbe5198e4688b10/examples/liquid.ini#L251-L260)
- Hoover: Named Entity Extraction -- automatically extract entities (persons,
  locations, organizations). Filter documents by the entities that appear in text.
  [Configuration for Named Entity Extraction and Language Detection](https://github.com/liquidinvestigations/node/blob/5ac3114bcedb8899e8326e332dbe5198e4688b10/examples/liquid.ini#L267-L279)
- Hoover: Machine Translation -- automatically translate first paragraph of
  document text between languages using LibreTranslate. Translation user
  interface is also available in Hoover, to manually translate text.
  [Configuration for Machine Translation](https://github.com/liquidinvestigations/node/blob/5ac3114bcedb8899e8326e332dbe5198e4688b10/examples/liquid.ini#L280-L296)
- Hoover: Generate and display thumbnails for small documents, pictures and
  Office files. The thumbnails are shown in the document result list, and in
  the document header.
  [Configuration for Thumbnail Generator](https://github.com/liquidinvestigations/node/blob/5ac3114bcedb8899e8326e332dbe5198e4688b10/examples/liquid.ini#L243-L246)
- Hoover: Convert Office files to PDF for easier viewing in the browser.
  [Configuration for PDF Preview](https://github.com/liquidinvestigations/node/blob/5ac3114bcedb8899e8326e332dbe5198e4688b10/examples/liquid.ini#L238-L242)
- App Permissions: User access to specific applications is now configurable by system admins, at the User or Group level.


### Improvements

- RocketChat platform now available in **RochetChat Mobile App for Android and IOS**. Push Notifications optional. [Steps to Enable RocketChat Push](https://github.com/liquidinvestigations/node/blob/5ac3114bcedb8899e8326e332dbe5198e4688b10/docs/RocketChat.md#mobile-notifications); [Configuration Flag for RocketChat Push](https://github.com/liquidinvestigations/node/blob/5ac3114bcedb8899e8326e332dbe5198e4688b10/examples/liquid.ini#L144-L149)
- RocketChat auto-logout interval is now configuarable separately. [Configuration for Rocketchat Auto-Logout](https://github.com/liquidinvestigations/node/blob/5ac3114bcedb8899e8326e332dbe5198e4688b10/examples/liquid.ini#L151-L155)
- User Management: new users can now be onboarded into Hoover collections
  without needing to wait for them to log in and open Hoover for the first time.
- Hoover Collections can now be configured individually for all the optional features. [New Per-Collection Configuration Flags](https://github.com/liquidinvestigations/node/blob/5ac3114bcedb8899e8326e332dbe5198e4688b10/examples/liquid.ini#L359-L372), [Example usage for all Collection Flags](https://github.com/liquidinvestigations/node/blob/5ac3114bcedb8899e8326e332dbe5198e4688b10/examples/liquid.ini#L387-L399).


### Bug Fixes

- Hoover: Fixed a bug limiting PDF viewer performance for large files.

--------------

## Version 0.15.0 (2021-11-10)


### New Features

- Hoover UI: added component to filter bucket values in aggregation results.


### Improvements

- Hoover UI: improved PDF viewer with new toolbar: added viewer for table of
  contents, in-document bookmarks, page thumbnails, and file attachments.
- Hoover UI: Help texts have been moved under "?" icons to save screen
  space.


### Bug Fixes

- Fixed a broken Hoover link pointing to the Hoover documentation page.


--------------

## Version 0.14.9 (2021-08-04)

This version brings Hoover UI improvements, as well as a new TOTP device change
form, and updated password change forms.

### New Features

- Hoover Insights View: page with aggregate data (file/data counts, common terms) for
  each collection, as well as advanced information on the processing status and ETA breakdown.


### Improvements

- Home Page: Users can now change their TOTP device without admin
  intervention. Users can also add multiple TOTP devices to the same account,
  and also remove old devices from their device list.
- Hoover: Added more icons (especially for tags) and updated some existing ones.
- Hoover: Changed File Browser (Finder) implementation into a custom one, to allow for
  future improvements.


## Version 0.14.8 (2021-06-02)

This version brings some Hoover UI improvements, and a script to
benchmark Hoover search times.


### New Features

- Hoover: Added command to benchmark Hoover search durations for a range of concurrent
  users and output a scatter plot with search time vs. searched collection size.

### Improvements

- Hoover UI: aggregation N/A bucket counts are now loaded when element becomes
  visible, instead of being loaded at search time. This should help reduce the
  search aggregation response times.
- Hoover UI: Added a configurable delay before retrying a failed request,
  default is 3s.

### Bug Fixes

- Hoover UI: Fixed bug where the "Email To" field would collapse multiple email
  addresses into a single string, obstructing the use of the "Open a new
  search for this term" button on that field.


### Upgrade Notes

In the `node` repository, run `pipenv install` to install the new plotting libraries.

Then, you can simply run `./liquid deploy`.

--------------

## Version 0.14.7 (2021-05-21)

This is a Hoover hotfix release that removes a problem with search queries that take more than 60s.

### Bug fixes

- Fixed an issue where requests (or other search queries) would return an error
  if the time exceeded 60s.

--------------

## Version 0.14.6 (2021-05-21)

This version is a Hoover hotfix release that adjusts various parameters for
shorter search times. This should help lower search times and have more
expansive searches fit the timeout.


### Improvements

- Added buttons to collapse categories and filter panes.
- Increased Hoover search timeout from 50s to 100s.
- Reduced Hoover search result bucket count from 100 to 44. More results can be
  still pulled when clicking on the "More" button.
- Reduced number of matched highlights per result from 3 to 2.
- Added management command `./liquid remove-last-es-data-node` to migrate data
  off the last Elasticsearch data server. This command automates some
  manual steps required for this operation.

--------------

## Version 0.14.5 (2021-05-05)

This is a Hoover UI hotfix release that brings more stability when searching in
a large number of collections. This is done by splitting aggregation search
requests into smaller ones, and by retrying timed out and failed requests.


### Improvements

- Added configuration option called `hoover_ui_agg_split` for splitting aggregations into consecutive requests.
- Added configuration option called `hoover_ui_search_retry` for maximum number of retries allowed for failed search requests. See the [example config file](https://github.com/liquidinvestigations/node/blob/v0.14.5/examples/liquid.ini) for more details.

## Version 0.14.4 (2021-04-28)

This is a Hoover UI hotfix release.

### Bug fixes

- Bring back search times closer previous known times by removing the implicit
  `NOT Public Tag: trash` filter from Search (added in `v0.14.0`). This tag will
  behave like any other public tag (same as before `v0.14.0`).

--------------

## Version 0.14.3 (2021-04-23)

This release brings Hoover UI and backend improvements, as well as re-written
[User Guides](https://github.com/liquidinvestigations/docs/wiki/User-Guide).
These User Guide pages include a new, more complete
[Hoover User Guide](https://github.com/liquidinvestigations/docs/wiki/User-Guide%3A-Hoover).
as well as updated User Guide pages for all other apps:
[Rocket.Chat](https://github.com/liquidinvestigations/docs/wiki/User-Guide%3A-Rocket.Chat),
[DokuWiki](https://github.com/liquidinvestigations/docs/wiki/User-Guide%3A-DokuWiki),
[CodiMD](https://github.com/liquidinvestigations/docs/wiki/User-Guide%3A-CodiMD),
[Nextcloud](https://github.com/liquidinvestigations/docs/wiki/User-Guide%3A-Nextcloud),
and
[Hypothesis](https://github.com/liquidinvestigations/docs/wiki/User-Guide%3A-Hypothesis).

### Improvements

- Added more structure to the aggregations by grouping them into categories. Only
  one list is shown at a time; the others only show aggregated hit counts.
- Added aggregations for document size and text word count.


### Bug Fixes

- Fixed UI bug where download links inside document children lists would be wrong.
- Fixed performance problem when unpacking very large `.tar` archives.
- Fixed bug where the `trash` tag couldn't be ignored when searching.
- Fixed bug where modified search query would be lost when changing Sort or Filters.
- Fixed bug where some documents would be opened in a new tab instead of downloaded.

--------------

## Version 0.14.2 (2021-03-30)

This release brings Hoover UI improvements and some
[new Hoover developer documentation](https://hoover-snoop2.readthedocs.io/en/latest/).

### Improvements

- Tags Autocomplete: When creating Tags, Hoover now displays the most commonly
  used Tags in the collection. New tags are added by clicking on them. Tags can
  be filtered by typing their partial name.
- Added new aggregation for Content Type (Mime Type).

### Bug Fixes

- Fixed bug where TIF images wouldn't render: added browser renderer for `.TIF`/`.TIFF` images.

--------------

## Version 0.14.1 (2021-03-16)

This is a bug fixing release targeting small Hoover UI issues.


### Improvements

- Added buckets for filtering search results by content type.

### Bug Fixes

- Added missing redirect rules for annotations made on Hoover documents before November 2020.
- Fixed a bug where Document pages would stay blank or loading in case of document fetching error. The pages will now display a proper error message.

--------------

## Version 0.14.0 (2021-03-12)

### New Features

All new features in this release are related to Hoover.

- Added buckets for missing values on all fields in left panel. Buckets are first in field, labeled in italic as *N/A*. Missing values for fields can be combined with all the other operators on that field: including, excluding.
- Added PDF viewer directly in document page. All old annotation URLs and old document viewer URLs now redirect to this page. Annotations now work in the PDF preview, even for scanned and OCR'd documents.
- Added Contextual Menu on fields under the Meta document tab. Options now include: adding field value to current search, opening a new search from field value. Timestamp fields now have options for filtering by that year, month, or week.
- Added thunderbird-like histogram displays for dates. Multiple buckets can be selected by clicking and dragging a line over them with the mouse. Once selected, the intervals can be used as a filter, or selected as individual buckets.


### Improvements

All improvements in this release are related to Hoover.

- Where possible, the fields from the Meta tab will now append their search to the filters buckets instead of the query string.
- Improve scrolling behavior for buckets. All buckets are now of a fixed height and contain more elements by default.
- When clicking on a PDF document, the UI jumps by default to its OCR PDF preview tab, so you can annotate the scans. The texts for the document are available below on the same tab.
- Mention collection in search result card.
- After selecting a collection, Hoover will now pull all the aggregation buckets, even if you didn't fill in a query yet.
- Added more progress spinner UI components for better interaction on slow servers.

### Bug Fixes

#### Hoover

- Fixed bug where Hoover PDF OCR preview would display an error for longer PDFs.
- Fixed bug where Hoover annotation tooltip info would display a negative number "Indexed -5 seconds ago" after clicking on lock.
- Removed Hoover Admin buttons for unsupported actions: adding/removing users and collections. User management is done in the home page, and collection management is done through the `liuqid.ini` configuration file.
- Fixed buttons for deleting a selected filter from the filter preview bubble.


#### Hypothesis

- Removed links from Hypothesis sidebar to facebook, twitter, google plus, `mailto:` to prevent accidental leaking. The icons currently still exist but error out with 404 on our page.

#### Rocketchat

- Replaced the `go.rocket.chat` channel invite URLs with our own rocketchat page to prevent accidental leaking. The links will now error out with 404 on our page.

### Upgrade Notes

We have upgraded Hoover's database to the latest version, and that means a dump/restore is needed as part of this deployment. The dump/restore won't be bigger than 500 MB, and won't take more than 5min.

- create full app backup before upgrading: `./liquid backup TMP_BACKUP --no-collections`
- follow ["clean reset" procedure](https://github.com/liquidinvestigations/docs/wiki/Maintenance#clean-reset) with [cluster version 0.13.1](https://github.com/liquidinvestigations/cluster/tree/v0.13.1)
- restore app backup after deploy is done: `./liquid restore-apps TMP_BACKUP`
- verify that Hoover groups and permissions are still correct by visiting Hoover Admin
- delete the backup: `rm -rf TMP_BACKUP`


--------------

## Versions 0.13 and older

Read the output of `git show v0.X.X` or the tag descriptions at https://github.com/liquidinvestigations/node/releases.
