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
    for name in config.collections:
        collection_dir = Path(options.dest).resolve() / f"collection-{name}"
        collection_dir.mkdir(parents=True, exist_ok=True)
        backup_collection(dest=collection_dir,
                          name=name,
                          save_blobs=options.blobs,
                          save_es=options.es,
                          save_pg=options.pg)


@retry()
def backup_collection_pg(dest, name):
    dest_file = dest / "pg.sql.gz"
    log.info(f"Dumping collection {name} pg to {dest_file}")
    cmd = (
        f"set -eo pipefail; ./liquid dockerexec snoop-{name}-pg "
        f"pg_dump -U snoop -Ox -t 'data_*' -t django_migrations "
        f"| gzip -1 > {dest_file}"
    )
    subprocess.check_call(["/bin/bash", "-c", cmd])


@retry()
def backup_collection_blobs(dest, name):
    dest_file = dest / "blobs.tgz"
    log.info(f"Dumping collection {name} blobs to {dest_file}")
    cmd = (
        f"set -eo pipefail; ./liquid dockerexec snoop-{name}-api "
        f"tar c -C blobs . "
        f"| gzip -1 > {dest_file}"
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
            f"./liquid dockerexec hoover-es "
            f"tar c -C /es_repo/backup-{name} . "
            f"| gzip -1 > {dest_file}"
        )
        subprocess.check_call(tar_cmd, shell=True)
    finally:
        es.delete(f"/_snapshot/backup-{name}/snapshot")
        es.delete(f"/_snapshot/backup-{name}")
        rm_cmd = (
            f"./liquid dockerexec hoover-es "
            f"rm -rf /es_repo/backup-{name} "
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
