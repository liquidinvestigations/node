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

### Create periodic backups

The [`./bin/periodic-backup.sh`](../bin/periodic-backup.sh) script has one required argument (`--dir`) and some optional arguments:
```
Usage: ./bin/periodic-backup.sh --dir exportdir [--rm] [--days N]
  --dir      backup directory, a date based subfolder will be added, e.g. exportdir/YYYYMMDD-HHmm
  --uploads  create a uploads collection backup, default disabled
  --rm       remove old backups, default disabled
  --days N   remove backups older than N days, default 60 days
```

Using `crontab -e` you can create periodic daily and weekly backups like this:
```shell
# Create a Liquid backup every day at 6am and keep old ones 7 days including uploads
0 6 * * * /opt/node/bin/periodic-backup.sh --dir /storage/backup/daily --rm --uploads --days 7

# Create a Liquid backup every week at 4am and remove old ones and keep the last log
0 4 * * 1 /opt/node/bin/periodic-backup.sh --dir /storage/backup/weekly --rm > /storage/backup/weekly/backup.log 2>&1
```

### Restoring application data

To restore application data:
```shell
./liquid restore-apps /tmp/backup-today
```


Data will only be restored if archives that exist at that location. This means
you can choose to only restore a certain application by placing its archives in
an empty directory and running this command on it.

### A possible backup strategy

Assuming most collections don't change after processing them for the first time,
you can create a full backup once for each collection. Except the so called
`uploads` collection or any other collection having `sync = True` in 
[`liquid.ini`](https://github.com/liquidinvestigations/node/blob/40963726bf79d3318496572e41f93543c93132f3/examples/liquid.ini#L252-L256).

Uploads and app data will change frequently and therefore need to be backed up regularly.
You can use our provided periodic backup script to create snapshots of app data as shown earlier.

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
