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

In the search UI admin interface, collections, the `testdata` should show up in the collections list. The `COUNT` field should start to grow after a while, when refreshing the page.


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
