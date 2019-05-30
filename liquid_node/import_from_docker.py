import logging
import shutil
from pathlib import Path

from liquid_node.configuration import config
from liquid_node.process import run

log = logging.getLogger(__name__)


def ensure_docker_setup_stopped():
    output = run('docker ps --filter "name=docker-setup_search"')
    if 'docker-setup_search' in output:
        raise RuntimeError('docker-compose is running in docker-setup. Please stop it.')


def validate_names(collections):
    new_collections = set([name.lower() for name in collections])
    intersection = new_collections.intersection(set(config.collections))
    if intersection:
        overwritten = ','.join(intersection)
        raise RuntimeError(f'The following collections would be overwritten: {overwritten}')

    names = {}
    conflicting = set()
    for name in collections:
        if name.lower() in names:
            conflicting.add(name.lower())
            names[name.lower()].append(name)
        else:
            names[name] = [name]
    if conflicting:
        groups = '; '.join([', '.join(names[conflict]) for conflict in conflicting])
        raise RuntimeError(f'These collections have conflicting names: {groups}. '
                           'Rename the conflicting collections in docker-setup.')


import_methods = ['copy', 'move', 'link']


def import_dir(src, dst, method='link'):
    if method  not in import_methods:
        raise RuntimeError(f'Invalid import method {method}')

    if dst.is_dir() or dst.is_symlink():
        raise RuntimeError(f'The destination directory {dst} already exists.')

    if method == 'copy':
        log.info(f'Copying from {src} to {dst}')
        shutil.copytree(str(src), str(dst))
    elif method == 'move':
        log.info(f'Moving {src} to {dst}')
        src.replace(dst)
    elif method == 'link':
        log.info(f'Linking {dst} to {src}')
        dst.symlink_to(src)


def import_index(docker_setup, method):
    log.info('Importing hoover search datadabase')
    pg_src = docker_setup / 'volumes' / 'search-pg'
    pg_dst = Path(config.liquid_volumes) / 'hoover' / 'pg'
    if pg_dst.is_symlink():
        pg_dst.unlink()
    if pg_dst.is_dir():
        shutil.rmtree(str(pg_dst))
    import_dir(pg_src, pg_dst, method)

    log.info('Importing elasticsearch index')
    es_src = docker_setup / 'volumes' / 'search-es'
    es_dst = Path(config.liquid_volumes) / 'hoover' / 'es'
    if es_dst.is_symlink():
        es_dst.unlink()
    if es_dst.is_dir():
        shutil.rmtree(str(es_dst))
    import_dir(es_src, es_dst, method)


def import_collection(name, settings, docker_setup, method='copy'):
    log.info(f'Importing collection {name}')

    node_name = name.lower()
    if name != node_name:
        log.info(f'Renaming "{name}" to "{node_name}"')

    collection_path = Path(config.liquid_volumes) / 'collections' / node_name
    if not collection_path.is_dir():
        collection_path.mkdir(parents=True)

    # copy the pg dir
    pg_src = docker_setup / 'volumes' / f'snoop-pg--{name}'
    pg_dst = collection_path / 'pg'
    log.info(f'Importing the collection "{name}" pg dir from docker-setup to node..')
    import_dir(pg_src, pg_dst, method)

    # copy the blobs dir
    blob_src = docker_setup / 'snoop-blobs' / name
    blob_dst = collection_path / 'blobs'
    log.info(f'Importing the collection "{name}" blobs dir from docker-setup to node..')
    import_dir(blob_src, blob_dst, method)


def add_collections_ini(collections):
    for name in collections:
        config.ini.add_section(f'collection:{name.lower()}')
    ini_path = config.root / 'liquid.ini'
    with ini_path.open(mode='w') as ini_file:
        config.ini.write(ini_file)
