import logging
import subprocess
import click
from pathlib import Path
from time import time, sleep
from .commands import halt
from .commands import deploy
from .configuration import config
from .nomad import nomad
from .jsonapi import JsonApi
from .util import retry

log = logging.getLogger(__name__)


SNOOP_PG_ALLOC = "hoover-deps:snoop-pg"
SNOOP_ES_ALLOC = "hoover-deps:es"
HYPOTHESIS_ES_ALLOC = "hypothesis-deps:es"
SNOOP_API_ALLOC = "hoover:snoop"


@click.group()
def backup_commands():
    pass


@backup_commands.command()
@click.option('--no-blobs', 'blobs', is_flag=True, default=True)
@click.option('--no-es', 'es', is_flag=True, default=True)
@click.option('--no-pg', 'pg', is_flag=True, default=True)
@click.option('--no-collections', 'backup_collections', is_flag=True, default=True)
@click.option('--collection', 'collections', multiple=True)
@click.option('--no-apps', 'apps', is_flag=True, default=True)
@click.argument('dest', required=True)
def backup(blobs, es, pg, backup_collections, collections, apps, dest):
    dest = Path(dest).resolve()
    dest.mkdir(parents=True, exist_ok=True)

    if not apps:
        log.warning('not backing up app data (--no-apps)')
    else:
        backup_sqlite3(dest / 'liquid-core.sqlite3.sql.gz', '/app/var/db.sqlite3', 'liquid:core')

        if config.is_app_enabled('hoover'):
            backup_pg(dest / 'hoover-search.pg.sql.gz', 'search', 'search', 'hoover-deps:search-pg')
            backup_pg(dest / 'hoover-snoop.pg.sql.gz', 'snoop', 'snoop', 'hoover-deps:snoop-pg')

        if config.is_app_enabled('codimd'):
            backup_pg(dest / 'codimd.pg.sql.gz', 'codimd', 'codimd', 'codimd-deps:postgres')

        if config.is_app_enabled('dokuwiki'):
            backup_files(dest / 'dokuwiki.tgz', '/bitnami/dokuwiki', [], 'dokuwiki:php')

        if config.is_app_enabled('hypothesis'):
            backup_dir = dest / "hypothesis"
            backup_dir.mkdir(parents=True, exist_ok=True)
            backup_pg(backup_dir / 'hypothesis.pg.sql.gz', 'hypothesis', 'hypothesis', 'hypothesis-deps:pg')
            backup_es(dest / 'hypothesis', 'hypothesis', '/_h_es', HYPOTHESIS_ES_ALLOC)

    if not backup_collections or not config.is_app_enabled('hoover'):
        log.warning('not backing up collection data (--no-collections)')
        return

    for collection_name in (collections or [x['name'] for x in config.snoop_collections]):
        collection_dir = dest / f"collection-{collection_name}"
        collection_dir.mkdir(parents=True, exist_ok=True)
        backup_collection(dest=collection_dir,
                          name=collection_name,
                          save_blobs=blobs,
                          save_es=es,
                          save_pg=pg)


def backup_collection(dest, name, save_blobs=True, save_es=True, save_pg=True):
    assert config.is_app_enabled('hoover')

    if save_pg:
        backup_collection_pg(dest, name)
    else:
        log.info("skipping saving pg")

    if save_es:
        backup_es(dest, name, "/_es", SNOOP_ES_ALLOC)
    else:
        log.info("skipping saving es")

    if save_blobs:
        backup_collection_blobs(dest, name)
    else:
        log.info("skipping saving blobs")


@backup_commands.command()
@click.argument('src')
@click.argument('name')
def restore_collection(src, name):
    log.info("restoring collection data from %s as %s", src, name)
    assert config.is_app_enabled('hoover')

    assert (name not in (c['name'] for c in config.snoop_collections)), \
        f"collection {name} already defined in liquid.ini, please remove it"

    config._validate_collection_name(name)

    src = Path(src).resolve()
    restore_collection_pg(src, name)
    restore_es(src, name, '/_es', SNOOP_ES_ALLOC)
    restore_collection_blobs(src, name)

    log.info("Collection data restored")
    log.info("Please add this collection to `./liquid.ini` and re-run `./liquid deploy`")


@backup_commands.command()
@click.pass_context
@click.argument('backup_root')
def restore_all_collections(ctx, backup_root):
    assert config.is_app_enabled('hoover')

    backup_root = Path(backup_root).resolve()
    PREFIX = 'collection-'
    for src in backup_root.iterdir():
        log.info("Collection is " + str(src))
        if src.is_dir() and src.name.startswith(PREFIX):
            name = src.name[len(PREFIX):]
            ctx.invoke(restore_collection, src=src, name=name)


@backup_commands.command()
@click.pass_context
@click.argument('src', required=True)
def restore_apps(ctx, src):
    src = Path(src).resolve()
    restore_sqlite3(src / 'liquid-core.sqlite3.sql.gz', '/app/var/db.sqlite3', 'liquid:core')
    nomad.restart('liquid', 'core')

    if config.is_app_enabled('hoover'):
        restore_pg(src / 'hoover-search.pg.sql.gz', 'search', 'search', 'hoover-deps:search-pg')
        nomad.restart('hoover', 'search')
        restore_pg(src / 'hoover-snoop.pg.sql.gz', 'snoop', 'snoop', 'hoover-deps:snoop-pg')
        nomad.restart('hoover', 'snoop')

    if config.is_app_enabled('codimd'):
        restore_pg(src / 'codimd.pg.sql.gz', 'codimd', 'codimd', 'codimd-deps:postgres')
        nomad.restart('codimd', 'codimd')
        nomad.restart('codimd-deps', 'postgres')

    if config.is_app_enabled('dokuwiki'):
        restore_files(src / 'dokuwiki.tgz', '/bitnami/dokuwiki', 'dokuwiki:php')
        nomad.restart('dokuwiki', 'php')

    if config.is_app_enabled('hypothesis'):
        restore_pg(src / 'hypothesis/hypothesis.pg.sql.gz', 'hypothesis', 'hypothesis', 'hypothesis-deps:pg')
        restore_es(src / 'hypothesis/', 'hypothesis', '/_h_es', HYPOTHESIS_ES_ALLOC)
        nomad.restart('hypothesis-deps', 'pg')
        nomad.restart('hypothesis-deps', 'es')

    log.info("Restore done; deploying")
    ctx.invoke(halt)
    ctx.invoke(deploy)


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
    log.info(f'Cmd is {cmd}')

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
def backup_es(dest, name, es_url_suffix, es_alloc_id):
    tmp_file = dest / "es.tgz.tmp"
    log.info(f"Dumping collection {name} es snapshot to {tmp_file}")
    es = JsonApi(f"http://{nomad.get_address()}:9990{es_url_suffix}")

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
        backup_files(tmp_file, f"/es_repo/backup-{name}", [], es_alloc_id)

        dest_file = dest / "es.tgz"
        tmp_file.rename(dest_file)
    finally:
        es.delete(f"/_snapshot/backup-{name}/snapshot")
        es.delete(f"/_snapshot/backup-{name}")
        rm_cmd = (
            f"./liquid dockerexec {es_alloc_id} "
            f"rm -rf /es_repo/backup-{name} "
        )
        subprocess.check_call(rm_cmd, shell=True)


@retry()
def restore_es(src, name, es_url_suffix, es_alloc_id):
    src_file = src / "es.tgz"
    if not src_file.is_file():
        log.warn(f"No es backup at {src_file}, skipping es restore")
        return
    log.info(f"Restoring {name} es snapshot from {src_file}")
    es = JsonApi(f"http://{nomad.get_address()}:9990{es_url_suffix}")

    try:
        # create snapshot repo
        es.put(f"/_snapshot/restore-{name}", {
            "type": "fs",
            "settings": {
                "location": f"/es_repo/restore-{name}",
            },
        })
        # populate its directory
        restore_files(src_file, f"/es_repo/restore-{name}", es_alloc_id)

        # examine unpacked snapshot
        resp = es.get(f"/_snapshot/restore-{name}/snapshot")
        assert len(resp["snapshots"]) == 1
        assert len(resp["snapshots"][0]["indices"]) == 1
        old_name = resp["snapshots"][0]["indices"][0]

        if es_alloc_id == SNOOP_ES_ALLOC:
            # reset index and close it
            reset_cmd = (
                f"./liquid dockerexec {SNOOP_API_ALLOC} "
                f"./manage.py resetcollectionindex {name}"
            )
            subprocess.check_call(reset_cmd, shell=True)
            es.post(f"/{name}/_close")
        else:
            # delete index instead of resetting it beacuse resetting isnt implemented
            old_index = es.get("/_cat/indices?format=json")
            old_index_name = old_index[0]["index"]
            es.delete(f"/{old_index_name}")

        # restore snapshot
        es.post(f"/_snapshot/restore-{name}/snapshot/_restore", {
            "indices": old_name,
            "include_global_state": False,
            "rename_pattern": ".+",
            "rename_replacement": name,
            "include_aliases": False,
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
            f"./liquid dockerexec {es_alloc_id} "
            f"rm -rf /es_repo/restore-{name} "
        )
        subprocess.check_call(rm_cmd, shell=True)
