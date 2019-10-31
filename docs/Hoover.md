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
