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
2. Run `./liquid shell hoover:snoop purge` -- use optional argument `--force` to skip manual confirmation. This command is [not implemented](https://github.com/liquidinvestigations/hoover-snoop2/issues/321).


## Tesseract OCR

Use the collection's `ocr_languages` config value to set any number of
languages for [tesseract 4.0
LSTM](https://tesseract-ocr.github.io/tessdoc/Data-Files#data-files-for-version-400-november-29-2016).
