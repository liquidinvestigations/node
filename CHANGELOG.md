# Liquid Investigations Change Log

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


## Version 0.14.7 (2021-05-21)

This is a Hoover hotfix release that removes a problem with search queries that take more than 60s.

### Bug fixes

- Fixed an issue where requests (or other search queries) would return an error
  if the time exceeded 60s.


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


## Version 0.14.1 (2021-03-16)

This is a bug fixing release targeting small Hoover UI issues.


### Improvements

- Added buckets for filtering search results by content type.

### Bug Fixes

- Added missing redirect rules for annotations made on Hoover documents before November 2020.
- Fixed a bug where Document pages would stay blank or loading in case of document fetching error. The pages will now display a proper error message.


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



## Versions 0.13 and older

Read the output of `git show v0.X.X` or the tag descriptions at https://github.com/liquidinvestigations/node/releases.
