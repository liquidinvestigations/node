# Hoover in the Liquid bundle

The Liquid Investigations bundle includes Hoover ([hoover-search][],
[hoover-snoop][], [hoover-ui][]). It's pre-configured with a collection named
`uploads` that is visible in [Nextcloud][] and indexed periodically by snoop.

[hoover-search]: https://github.com/liquidinvestigations/hoover-search
[hoover-snoop]: https://github.com/liquidinvestigations/hoover-snoop2
[hoover-ui]: https://github.com/liquidinvestigations/hoover-ui
[Nextcloud]: ./Nextcloud.md

## Example: Testdata
Set up the `testdata` collection. First download the data:

```shell
mkdir -p collections
git clone https://github.com/liquidinvestigations/testdata collections/testdata
```

Next define the collection in `liquid.ini`:

```ini
[collection:testdata]
process = True
```

Then let the `deploy` command pick up the new collection:

```shell
./liquid deploy
```

## Adding collections

All collections are loaded from the `liquid_collections` directory configured in `liquid.ini`.
The directories directly under `liquid_collections` can also be symlinks.

To add new collections simply append to the `liquid.ini` file:

```ini
[collection:always-changes]
process = True
sync = True

[collection:static-data]
process = True
```

... and run `./liquid deploy`. The requested number of workers and their dependencies will be deployed on the Nomad cluster; see them run on the Nomad UI.

---

The two parameters control:
- `workers`: the Snoop worker count for this collection
- `sync`: wether the workers should track the collection data and re-process changed/new documents

The collection names must follow the [elasticsearch index naming guide](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/indices-create-index.html#indices-create-index), namely **lowercase alphanumeric**, **dashes** and **numbers** only.


## Removing collections

In order to remove a collection, take the following steps:
1. Remove the corresponding collection section from the `liquid.ini` file.
2. Run `./liquid collectionsgc`
3. Run `./liquid purge`


## Tesseract Batch OCR

**Warning:** This implementation outputs data in the `liquid_collection` directory for the selected collection. 

Use the following commands to run Tesseract OCR on the collection data's
`/data/ocr/<language-code>` paths, outputting PDFs its `ocr` directory.

```shell
./liquid launchocr testdata
./liquid shell snoop-testdata-api ./manage.py createocrsource tesseract-batch /opt/hoover/collection/ocr/tesseract-batch
./liquid shell snoop-testdata-api ./manage.py rundispatcher
```

To run the batch job periodically use `--periodic=@daily` (or any other [cron expression accepted by Nomad](https://www.nomadproject.io/docs/job-specification/periodic.html#cron)).
To stop it from staturating 12 cores for each collection, start (or update) the jobs with `--workers 1 --threads_per_worker 1 --nice 10`.
