import logging
import argparse
import subprocess
from pathlib import Path
from time import time, sleep

from liquid_node.configuration import config
from liquid_node.nomad import nomad
from liquid_node.jsonapi import JsonApi
from .util import retry
from . import commands

log = logging.getLogger(__name__)


def backup(*args):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--no-blobs', action='store_false', dest='blobs')
    parser.add_argument('--no-es', action='store_false', dest='es')
    parser.add_argument('--no-pg', action='store_false', dest='pg')
    parser.add_argument('--no-collections', action='store_false', dest='collections')
    parser.add_argument('--no-apps', action='store_false', dest='apps')
    parser.add_argument('dest')
    options = parser.parse_args(args)
    dest = Path(options.dest).resolve()
    dest.mkdir(parents=True, exist_ok=True)

    if not options.apps:
        log.warning('not backing up app data (--no-apps)')
    else:
        backup_sqlite3(dest / 'liquid-core.sqlite3.sql.gz', '/app/var/db.sqlite3', 'liquid:core')
        backup_pg(dest / 'hoover-search.pg.sql.gz', 'search', 'search', 'hoover-deps:search-pg')
        backup_pg(dest / 'hoover-snoop.pg.sql.gz', 'snoop', 'snoop', 'hoover-deps:snoop-pg')

        if config.is_app_enabled('codimd'):
            backup_pg(dest / 'codimd.pg.sql.gz', 'codimd', 'codimd', 'codimd:postgres')

        if config.is_app_enabled('dokuwiki'):
            backup_files(dest / 'dokuwiki.tgz', '/bitnami/dokuwiki', [], 'dokuwiki:php')

    if not options.collections:
        log.warning('not backing up collection data (--no-collections)')
        return

    for collection in config.snoop_collections:
        name = collection['name']

        collection_dir = dest / f"collection-{name}"
        collection_dir.mkdir(parents=True, exist_ok=True)
        backup_collection(dest=collection_dir,
                          name=name,
                          save_blobs=options.blobs,
                          save_es=options.es,
                          save_pg=options.pg)


def restore_apps(*args):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('src')
    options = parser.parse_args(args)
    src = Path(options.src).resolve()

    restore_sqlite3(src / 'liquid-core.sqlite3.sql.gz', '/app/var/db.sqlite3', 'liquid:core')
    nomad.restart('liquid', 'core')
    restore_pg(src / 'hoover-search.pg.sql.gz', 'search', 'search', 'hoover-deps:search-pg')
    nomad.restart('hoover', 'search')
    restore_pg(src / 'hoover-snoop.pg.sql.gz', 'snoop', 'snoop', 'hoover-deps:snoop-pg')
    nomad.restart('hoover', 'snoop')

    if config.is_app_enabled('codimd'):
        restore_pg(src / 'codimd.pg.sql.gz', 'codimd', 'codimd', 'codimd:postgres')
        nomad.restart('codimd', 'codimd')

    if config.is_app_enabled('dokuwiki'):
        restore_files(src / 'dokuwiki.tgz', '/bitnami/dokuwiki', 'dokuwiki:php')
        nomad.restart('dokuwiki', 'php')

    log.info("Restore done; deploying")
    commands.halt()
    commands.deploy()


SNOOP_PG_ALLOC = "hoover-deps:snoop-pg"
SNOOP_ES_ALLOC = "hoover-deps:es"
SNOOP_API_ALLOC = "hoover:snoop"


@retry()
def backup_pg(dest_file, username, dbname, alloc):
    tmp_file = Path(str(dest_file) + '.tmp')
    log.info(f"Dumping postgres from alloc {alloc} user {username} db {dbname} to {tmp_file}")
    cmd = (
        f"set -exo pipefail; ./liquid dockerexec {alloc} "
        f"pg_dump -U {username} {dbname} -Ox "
        f"| gzip -1 > {tmp_file}"
    )
    subprocess.check_call(["/bin/bash", "-c", cmd])

    log.info(f"Verify {tmp_file} by printing contents to /dev/null")
    subprocess.check_call(["/bin/bash", "-c", f"zcat {tmp_file} > /dev/null"])

    log.info(f"Renaming {tmp_file} to {dest_file}")
    tmp_file.rename(dest_file)


@retry()
def backup_sqlite3(dest_file, dbname, alloc):
    tmp_file = Path(str(dest_file) + '.tmp')
    log.info(f"Dumping sqlite3 from alloc {alloc} db {dbname} to {tmp_file}")
    cmd = (
        f"set -exo pipefail; ./liquid dockerexec {alloc} "
        f"sqlite3 -readonly -batch {dbname} .dump "
        f"| gzip -1 > {tmp_file}"
    )
    subprocess.check_call(["/bin/bash", "-c", cmd])

    log.info(f"Verify {tmp_file} by printing contents to /dev/null")
    subprocess.check_call(["/bin/bash", "-c", f"zcat {tmp_file} > /dev/null"])

    log.info(f"Renaming {tmp_file} to {dest_file}")
    tmp_file.rename(dest_file)


@retry()
def restore_sqlite3(src_file, dbname, alloc):
    if not src_file.is_file():
        log.warn(f"No sqlite3 backup at {src_file}, skipping sqlite .restore")
        return

    log.info(f"Restore sqlite3 from {src_file} to alloc {alloc} db {dbname}")
    cmds = (
        f"./liquid dockerexec {alloc} rm -f {dbname}",
        (
            f"set -exo pipefail; ./liquid dockerexec {alloc} bash -c "
            f"'set -exo pipefail; zcat | sqlite3 -batch {dbname}' < {src_file}"
        ),
    )

    for cmd in cmds:
        subprocess.check_call(["/bin/bash", "-c", cmd])


@retry()
def restore_pg(src_file, username, dbname, alloc):
    if not src_file.is_file():
        log.warn(f"No pg backup at {src_file}, skipping pgrestore")
        return

    log.info(f"Restore postgres from {src_file} to alloc {alloc} user {username} db {dbname}")
    cmd = (
        f"set -eo pipefail; ./liquid dockerexec {alloc} bash -c "
        f"'set -exo pipefail;"
        f"dropdb -U {username} --if-exists {dbname};"
        f" createdb -U {username} {dbname};"
        f" zcat | psql -U {username} {dbname}' > /dev/null "
        f"< {src_file}"
    )
    subprocess.check_call(["/bin/bash", "-c", cmd])


def backup_collection_pg(dest, name):
    backup_pg(dest / "pg.sql.gz", "snoop", "collection_" + name, SNOOP_PG_ALLOC)


def restore_collection_pg(src, name):
    restore_pg(src / "pg.sql.gz", "snoop", "collection_" + name, SNOOP_PG_ALLOC)


@retry()
def backup_files(dest_file, path, exclude, alloc):
    tmp_file = Path(str(dest_file) + '.tmp')
    log.info(f"Dumping path {path} from alloc {alloc} to {tmp_file}")
    # tar raises a warning with an exit code of 1 if
    # the files change during archive creation.
    # We know we only create the files with an atomic move, so
    # we can ignore this error with `|| [[ $? -eq 1 ]]`.
    exclude_str = ' '.join(' --exclude ' + p for p in exclude)
    cmd = (
        f"set -exo pipefail; ( ./liquid dockerexec {alloc} "
        f"tar c {exclude_str} -C {path} . || [[ $? -eq 1 ]] ) "
        f"| gzip -1 > {tmp_file}"
    )
    subprocess.check_call(["/bin/bash", "-c", cmd])

    log.info(f"Verify {tmp_file} by listing contents to /dev/null")
    subprocess.check_call(["/bin/bash", "-c", f"tar -ztvf {tmp_file} > /dev/null"])

    log.info(f"Renaming {tmp_file} to {dest_file}")
    tmp_file.rename(dest_file)


@retry()
def restore_files(src_file, path, alloc):
    log.info(f"Restoring from {src_file} path {path} to alloc {alloc}")
    cmd = (
        f"set -eo pipefail; ./liquid dockerexec {alloc} bash -c "
        f"'set -exo pipefail; rm -rf {path};"
        f" mkdir {path}; tar xz -C {path}' "
        f"< {src_file}"
    )
    subprocess.check_call(["/bin/bash", "-c", cmd])


def backup_collection_blobs(dest, name):
    log.info(f"Dumping collection {name} blobs to {dest}")
    backup_files(dest / "blobs.tgz", "blobs/" + name, ['./tmp'], SNOOP_API_ALLOC)


def restore_collection_blobs(src, name):
    src_file = src / "blobs.tgz"
    if not src_file.is_file():
        log.warn(f"No blobs backup at {src_file}, skipping blob restore")
        return
    log.info(f"Restoring collection {name} blobs from {src_file}")
    restore_files(src / "blobs.tgz", "blobs/" + name, SNOOP_API_ALLOC)


def is_index_available(es_client, name):
    shards = es_client.get(f'/_cat/shards/{name}?format=json')
    # check that no primary shards are INITIALIZING, RELOCATING or UNASSIGNED
    return not any(s['prirep'] == 'p' and s['state'] != "STARTED"
                   for s in shards)


@retry()
def backup_collection_es(dest, name):
    tmp_file = dest / "es.tgz.tmp"
    log.info(f"Dumping collection {name} es snapshot to {tmp_file}")
    es = JsonApi(f"http://{nomad.get_address()}:9990/_es")

    # wait until the index is available
    log.info(f'Waiting until shards for index "{name}" are all available.')
    while not is_index_available(es, name):
        log.warning(f'index "{name}" has UNASSIGNED shards; waiting...')
        sleep(3)
    log.info('All primary shards started. Running backup...')

    try:
        es.put(f"/_snapshot/backup-{name}", {
            "type": "fs",
            "settings": {
                "location": f"/es_repo/backup-{name}",
            },
        })
        es.put(f"/_snapshot/backup-{name}/snapshot", {
            "indices": name,
            "include_global_state": False,
        })
        t0 = time()
        while True:
            res = es.get(f"/_snapshot/backup-{name}/snapshot")
            snapshot = res["snapshots"][0]
            if snapshot.get("state") == "IN_PROGRESS":
                sleep(1)
                continue
            elif snapshot.get("state") == "SUCCESS":
                break
            else:
                raise RuntimeError("Something went wrong: %r" % snapshot)
        log.info(f"Snapshot done in {int(time()-t0)}s")

        backup_files(tmp_file, f"/es_repo/backup-{name}", [], SNOOP_ES_ALLOC)

        dest_file = dest / "es.tgz"
        tmp_file.rename(dest_file)
    finally:
        es.delete(f"/_snapshot/backup-{name}/snapshot")
        es.delete(f"/_snapshot/backup-{name}")
        rm_cmd = (
            f"./liquid dockerexec {SNOOP_ES_ALLOC} "
            f"rm -rf /es_repo/backup-{name} "
        )
        subprocess.check_call(rm_cmd, shell=True)


@retry()
def restore_collection_es(src, name):
    src_file = src / "es.tgz"
    if not src_file.is_file():
        log.warn(f"No es backup at {src_file}, skipping es restore")
        return
    log.info(f"Restoring collection {name} es snapshot from {src_file}")
    es = JsonApi(f"http://{nomad.get_address()}:9990/_es")

    try:
        # create snapshot repo
        es.put(f"/_snapshot/restore-{name}", {
            "type": "fs",
            "settings": {
                "location": f"/es_repo/restore-{name}",
            },
        })
        # populate its directory
        restore_files(src_file, f"/es_repo/restore-{name}", SNOOP_ES_ALLOC)

        # examine unpacked snapshot
        resp = es.get(f"/_snapshot/restore-{name}/snapshot")
        assert len(resp["snapshots"]) == 1
        assert len(resp["snapshots"][0]["indices"]) == 1
        old_name = resp["snapshots"][0]["indices"][0]

        # reset index and close it
        reset_cmd = (
            f"./liquid dockerexec {SNOOP_API_ALLOC} "
            f"./manage.py resetcollectionindex {name}"
        )
        subprocess.check_call(reset_cmd, shell=True)
        es.post(f"/{name}/_close")

        # restore snapshot
        es.post(f"/_snapshot/restore-{name}/snapshot/_restore", {
            "indices": old_name,
            "include_global_state": False,
            "rename_pattern": ".+",
            "rename_replacement": name,
        })

        # wait for completion
        t0 = time()
        while True:
            res = es.get(f"/{name}/_recovery")
            if name in res:
                if all(s["stage"] == "DONE" for s in res[name]["shards"]):
                    break
            sleep(1)
            continue
        es.post(f"/{name}/_open")
        log.info(f"Restore done in {int(time()-t0)}s")
    finally:
        es.delete(f"/_snapshot/restore-{name}/snapshot")
        es.delete(f"/_snapshot/restore-{name}")
        rm_cmd = (
            f"./liquid dockerexec {SNOOP_ES_ALLOC} "
            f"rm -rf /es_repo/restore-{name} "
        )
        subprocess.check_call(rm_cmd, shell=True)


def backup_collection(dest, name, save_blobs=True, save_es=True, save_pg=True):
    if save_pg:
        backup_collection_pg(dest, name)
    else:
        log.info("skipping saving pg")

    if save_es:
        backup_collection_es(dest, name)
    else:
        log.info("skipping saving es")

    if save_blobs:
        backup_collection_blobs(dest, name)
    else:
        log.info("skipping saving blobs")


def restore_collection(src, name):
    log.info("restoring collection data from %s as %s", src, name)

    assert (name not in (c['name'] for c in config.snoop_collections)), \
        f"collection {name} already defined in liquid.ini, please remove it"

    config._validate_collection_name(name)

    src = Path(src).resolve()
    restore_collection_pg(src, name)
    restore_collection_es(src, name)
    restore_collection_blobs(src, name)

    log.info("Collection data restored")
    log.info("Please add this collection to `./liquid.ini` and re-run `./liquid deploy`")


def restore_all_collections(backup_root):
    backup_root = Path(backup_root).resolve()
    PREFIX = 'collection-'
    for src in backup_root.iterdir():
        if src.is_dir() and src.name.startswith(PREFIX):
            name = src.name[len(PREFIX):]
            restore_collection(src, name)
