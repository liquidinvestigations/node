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


## Corrupted postgres database index

Some apps use Postgres, a database system that sometimes gets corrupted indexes
when its server crashes under load. The data is not lost, but you will need to
run `reindexdb` commands on the database servers.

These commands should be run periodically (once per year) for the apps. You should also run them for individual snoop databases where 

- search:  `./liquid dockerexec hoover-deps:search-pg reindexdb -a -U search`
- snoop, everything: `./liquid dockerexec hoover-deps:snoop-pg reindexdb -a -U snoop`
- snoop, just collection `testdata`: `./liquid dockerexec hoover-deps:snoop-pg reindexdb -U snoop -v collection_testdata`
- codimd:  `./liquid dockerexec codimd-deps:postgres reindexdb -a -U codimd`
- hypothesis:  `./liquid dockerexec hypothesis-deps:pg reindexdb -a -U hypothesis`

 Warning: the reindex operation for large Snoop collections will take some 3-5h /
1M documents, regardless of their size. Please turn all snoop workers off before running this step.
