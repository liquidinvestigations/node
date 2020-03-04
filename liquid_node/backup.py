import logging
import argparse
import subprocess
from pathlib import Path
from time import time, sleep

from liquid_node.configuration import config
from liquid_node.nomad import nomad
from liquid_node.jsonapi import JsonApi

log = logging.getLogger(__name__)


def retry(count=4, wait_sec=5, exp=2):
    def _retry(f):
        def wrapper(*args, **kwargs):
            current_wait = wait_sec
            for i in range(count):
                try:
                    return f(*args, **kwargs)
                except Exception as e:
                    log.exception(e)
                    if i == count - 1:
                        raise

                    log.warning("#%s/%s retrying in %s sec", i + 1, count, current_wait)
                    current_wait = int(current_wait * exp)
                    sleep(current_wait)
                    continue
        return wrapper

    return _retry


def backup(*args):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--no-blobs', action='store_false', dest='blobs')
    parser.add_argument('--no-es', action='store_false', dest='es')
    parser.add_argument('--no-pg', action='store_false', dest='pg')
    parser.add_argument('dest')
    options = parser.parse_args(args)
    for collection in config.snoop_collections:
        name = collection['name']

        collection_dir = Path(options.dest).resolve() / f"collection-{name}"
        collection_dir.mkdir(parents=True, exist_ok=True)
        backup_collection(dest=collection_dir,
                          name=name,
                          save_blobs=options.blobs,
                          save_es=options.es,
                          save_pg=options.pg)


SNOOP_PG_ALLOC = "hoover-deps:snoop-pg"
SNOOP_ES_ALLOC = "hoover-deps:es"
SNOOP_API_ALLOC = "hoover:snoop"


@retry()
def backup_collection_pg(dest, name):
    dest_file = dest / "pg.sql.gz"
    log.info(f"Dumping collection {name} pg to {dest_file}")
    cmd = (
        f"set -eo pipefail; ./liquid dockerexec {SNOOP_PG_ALLOC} "
        f"pg_dump -U snoop collection_{name} -Ox "
        f"| gzip -1 > {dest_file}"
    )
    subprocess.check_call(["/bin/bash", "-c", cmd])


@retry()
def restore_collection_pg(src, name):
    src_file = src / "pg.sql.gz"
    if not src_file.is_file():
        log.warn(f"No pg backup at {src_file}, skipping pgrestore")
        return
    log.info(f"Restoring collection {name} pg from {src_file}")
    cmd = (
        f"set -eo pipefail; ./liquid dockerexec {SNOOP_PG_ALLOC} bash -c "
        f"'set -exo pipefail;"
        f"dropdb -U snoop --if-exists collection_{name};"
        f" createdb -U snoop collection_{name};"
        f" zcat | psql -U snoop collection_{name}' > /dev/null "
        f"< {src_file}"
    )
    subprocess.check_call(["/bin/bash", "-c", cmd])


@retry()
def backup_collection_blobs(dest, name):
    dest_file = dest / "blobs.tgz"
    log.info(f"Dumping collection {name} blobs to {dest_file}")
    # tar raises a warning with an exit code of 1 if
    # the files change during archive creation.
    # We know we only create the files with an atomic move, so
    # we can ignore this error with `|| [[ $? -eq 1 ]]`.
    cmd = (
        f"set -exo pipefail; ( ./liquid dockerexec {SNOOP_API_ALLOC} "
        f"tar c --exclude ./tmp -C blobs/{name} . || [[ $? -eq 1 ]] ) "
        f"| gzip -1 > {dest_file}"
    )
    subprocess.check_call(["/bin/bash", "-c", cmd])


@retry()
def restore_collection_blobs(src, name):
    src_file = src / "blobs.tgz"
    if not src_file.is_file():
        log.warn(f"No blobs backup at {src_file}, skipping blob restore")
        return
    log.info(f"Restoring collection {name} blobs from {src_file}")
    cmd = (
        f"set -eo pipefail; ./liquid dockerexec {SNOOP_API_ALLOC} bash -c "
        f"'set -exo pipefail; rm -rf blobs/{name};"
        f" mkdir blobs/{name}; tar xz -C blobs/{name}' "
        f"< {src_file}"
    )
    subprocess.check_call(["/bin/bash", "-c", cmd])


@retry()
def backup_collection_es(dest, name):
    dest_file = dest / "es.tgz"
    log.info(f"Dumping collection {name} es snapshot to {dest_file}")
    es = JsonApi(f"http://{nomad.get_address()}:8765/_es")
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
        tar_cmd = (
            f"./liquid dockerexec {SNOOP_ES_ALLOC} "
            f"tar c -C /es_repo/backup-{name} . "
            f"| gzip -1 > {dest_file}"
        )
        subprocess.check_call(tar_cmd, shell=True)
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
    es = JsonApi(f"http://{nomad.get_address()}:8765/_es")
    try:
        # create snapshot repo
        es.put(f"/_snapshot/restore-{name}", {
            "type": "fs",
            "settings": {
                "location": f"/es_repo/restore-{name}",
            },
        })
        # populate its directory
        tar_cmd = (
            f"./liquid dockerexec {SNOOP_ES_ALLOC} bash -c "
            f"'set -exo pipefail;"
            f" rm -rf /es_repo/restore-{name};"
            f" mkdir /es_repo/restore-{name};"
            f" tar xz -C /es_repo/restore-{name} ' "
            f"< {src_file}"
        )
        subprocess.check_call(tar_cmd, shell=True)

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


def restore_all_collections(backup_root):
    backup_root = Path(backup_root).resolve()
    PREFIX = 'collection-'
    for src in backup_root.iterdir():
        if src.is_dir() and src.name.startswith(PREFIX):
            name = src.name[len(PREFIX):]
            restore_collection(src, name)
