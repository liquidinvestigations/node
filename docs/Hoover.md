# Hoover in the Liquid bundle

The Liquid Investigations bundle includes Hoover ([hoover-search][],
[hoover-snoop][], [hoover-ui][]). It's pre-configured with a collection named
`uploads` that is visible in [Nextcloud][] and indexed periodically by snoop.

[hoover-search]: https://github.com/liquidinvestigations/hoover-search
[hoover-snoop]: https://github.com/liquidinvestigations/hoover-snoop2
[hoover-ui]: https://github.com/liquidinvestigations/hoover-ui
[Nextcloud]: ./Nextcloud.md

## Testdata
Set up the `testdata` collection. First download the data:

```shell
mkdir -p collections
git clone https://github.com/liquidinvestigations/testdata collections/testdata
```

Next define the collection in `liquid.ini`:

```ini
[collection:testdata]
workers = 1
```

Then let the `deploy` command pick up the new collection:

```shell
./liquid deploy
```


## Removing collections
In order to remove a collection, take the following steps:
1. Remove the corresponding collection section from the `liquid.ini` file.
2. Run `./liquid collectionsgc`
3. Run `./liquid purge`


### Tesseract Batch OCR

Use the following commands to run Tesseract OCR on the collection data's
`/data/ocr/<language-code>` paths, outputting PDFs its `ocr` directory.

```shell
./liquid launchocr testdata
./liquid shell snoop-testdata-api ./manage.py createocrsource tesseract-batch /opt/hoover/collection/ocr/tesseract-batch
./liquid shell snoop-testdata-api ./manage.py rundispatcher
```

To run the batch job periodically use `--periodic=@daily` (or any other [cron expression accepted by Nomad](https://www.nomadproject.io/docs/job-specification/periodic.html#cron)).
To stop it from staturating 12 cores for each collection, start (or update) the jobs with `--workers 1 --threads_per_worker 1 --nice 10`.
