import logging
from pathlib import Path
import shutil
from subprocess import CalledProcessError, DEVNULL
import sys

from .configuration import config
from .docker import docker
from .process import run


log = logging.getLogger(__name__)


def get_search_collections():
    """Returns a list of collections found in hoover search."""

    try:
        return run(docker.exec_command('hoover-search', './manage.py', 'listcollections'),
                   shell=False, stderr=DEVNULL).split()
    except CalledProcessError as e:
        print(e.output.decode('latin1'), file=sys.stderr)
        raise


def get_collections_to_purge():
    """Returns a set of collections to purge."""

    ini_collections = set(config.collections.keys())

    collections_dir = Path(config.liquid_volumes) / 'collections'
    volumes = set([subdir.name for subdir in collections_dir.iterdir() if subdir.is_dir()])

    return volumes - ini_collections


def purge_collection(name):
    """Purge data for the given collection, remove it from hoover search."""

    if name in get_search_collections():
        docker.shell('hoover-search', './manage.py', 'removecollection', name)
        log.info(f'Collection {name} was removed from hoover search.')

    collection_volume = Path(config.liquid_volumes) / 'collections' / name
    if collection_volume.is_dir():
        shutil.rmtree(collection_volume)
    log.info(f'Collection {name} data was purged.')


def push_collections_titles():
    for name, settings in config.collections.items():
        if 'title' in settings:
            try:
                cmd = docker.exec_command('hoover-search', './manage.py',
                                          'setcollectiontitle', name,
                                          settings['title'])
                return run(cmd, shell=False).split()
            except CalledProcessError as e:
                log.error(e.output.decode('latin1'))
