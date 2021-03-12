# Liquid Investigations Change Log

## unreleased

## version 0.14.0 (2021-03-12)

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



## versions 0.13 and older

Read the output of `git show v0.X.X` or the tag descriptions at https://github.com/liquidinvestigations/node/releases.
