## Backups
To create a backup of the cluster:

```shell
./liquid backup /tmp/backup-today
```

The backup includes all Hoover collections (elasticsearch index, postgres
database, blob files on disk).

To restore a collection:
```shell
./liquid restore_collection /tmp/backup-today/collection-testdata new-collection-name
```
