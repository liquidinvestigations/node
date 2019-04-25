# CLI commands test procedure

Setup the test data collection (see Readme) and run the tests in the given order.

## Test `deploy`

Run the following command:
```shell
./liquid deploy
```

The output should look like this:
```
2019-04-25 11:49:16 INFO Starting hoover...
2019-04-25 11:49:16 INFO Starting hoover-ui...
2019-04-25 11:49:16 INFO Starting liquid...
2019-04-25 11:49:16 INFO Starting collection-testdata...
```

In the nomad admin UI all jobs (`hoover`, `hoover-ui`, `liquid`, `collection-testdata`) should start succesfully.

## Test `initcollection`

Run the following command:
```shell
./liquid initcollection testdata
```

The output should look like this:
```
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, data, sessions
Running migrations:
  Applying contenttypes.0001_initial... OK
...
```

In the search UI admin interface, collections, the `testdata` should show up in the collections list. The `COUNT` field should start to grow after a while, when refreshing the page.

## Test `gc`

In `liquid.ini` file remove the lines:
```
[collection:testdata]
workers = 1
```

Run the following command:
```shell
./liquid gc
```

The output should look like this:
```
2019-04-25 14:13:48 INFO Stopping collection-testdata...
```

In the `nomad` UI the `collection-testdata` job should be dead.

## Test `purge`

Run the following command:
```shell
./liquid purge --force
```

The output of this command should look like this:
```
Purging collection testdata1...
2019-04-25 14:17:53 INFO Collection testdata1 was removed from hoover search.
2019-04-25 14:17:53 INFO Collection testdata1 data was purged.
```

The folder `volumes/collections/testdata` should be removed and the collection should be removed from the search collections (see search admin UI - collections).

## Test `halt`

Run the following command:
```shell
./liquid halt
```

The output of this command should look like this:
```
2019-04-25 14:28:40 INFO Stopping hoover...
2019-04-25 14:28:40 INFO Stopping hoover-ui...
2019-04-25 14:28:40 INFO Stopping liquid...
```

In the nomad admin UI all jobs (`hoover`, `hoover-ui`, `liquid`, `collection-testdata`) should be dead.
