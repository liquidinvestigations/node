## Backups

To create a complete backup of the cluster data:

```shell
./liquid backup /tmp/backup-today
```

The backup includes all Hoover collections (elasticsearch index, postgres
database, blob files on disk) and all application data (excepting the chat logs
and internal message queues).

### Partial backups

```
The "./liquid backup" command has optional arguments:
  -h, --help            show this help message and exit
  --no-blobs            omit backing up collection data blobs
  --no-es               omit backing up collection elasticsearch indexes
  --no-pg               omit backing up collection databases
  --no-collections      omit backing up any collection data
  --collection C        only backup data for collection C. This argument can be provided multiple times
  --no-apps             omit backing up application data
```


### Restoring a single collection

To restore a collection:
```shell
./liquid restore-collection /tmp/backup-today/collection-testdata new-collection-name
```


### Restoring application data

To restore application data:
```shell
./liquid restore-apps /tmp/backup-today
```


Data will only be restored if archives that exist at that location. This means
you can choose to only restore a certain application by placing its archives in
an empty directory and running this command on it.
