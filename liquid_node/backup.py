import logging
import subprocess
from pathlib import Path

from liquid_node.configuration import config

log = logging.getLogger(__name__)


def backup(dest, *targets):
    dest = Path(dest).resolve()
    dest.mkdir(parents=True, exist_ok=True)
    for target in targets:
        if target.startswith("collection:"):
            name = target.split(":", 1)[1]
            backup_collection(dest, name)
        else:
            raise RuntimeError("Can't back up %r" % target)


def backup_collection_pg(dest, name):
    dest_file = dest / f"collection-{name}-pg.sql"
    log.info(f"Dumping collection {name} pg to {dest_file}")
    cmd = (
        f"./liquid dockerexec snoop-testdata-pg "
        f"pg_dump -U snoop -Ox -t 'data_*' -t django_migrations "
        f"> {dest_file}"
    )
    subprocess.check_call(cmd, shell=True)


def backup_collection_blobs(dest, name):
    dest_file = dest / f"collection-{name}-blobs.tar"
    log.info(f"Dumping collection {name} blobs to {dest_file}")
    cmd = (
        f"./liquid dockerexec snoop-testdata-api "
        f"tar c -C /opt/hoover/collection/data . "
        f"> {dest_file}"
    )
    subprocess.check_call(cmd, shell=True)


def backup_collection(dest, name):
    backup_collection_pg(dest, name)
    backup_collection_blobs(dest, name)
