import logging
from getpass import getpass
import os
import base64
import json

from .collections import get_collections_to_purge, purge_collection
from .configuration import config
from .consul import consul
from .jobs import get_job, get_collection_job
from .nomad import nomad
from .process import run
from .util import first
from .collections import get_search_collections
from .docker import docker
from .vault import vault


log = logging.getLogger(__name__)

core_auth_apps = [
    {
        'name': 'authdemo',
        'vault_path': 'authdemo/auth.oauth2',
        'callback': f'http://authdemo.{config.liquid_domain}/__auth/callback',
    },
    {
        'name': 'hoover',
        'vault_path': 'hoover/search.oauth2',
        'callback': (
            f'http://hoover.{config.liquid_domain}'
            '/accounts/oauth2-exchange/'
        ),
    },
]


def random_secret():
    """ Generate a crypto-quality 256-bit random string. """
    return str(base64.b16encode(os.urandom(32)), 'latin1').lower()


def ensure_secret_key(path):
    if not vault.read(path):
        log.info(f"Generating secrets for {path}")
        vault.set(path, {'secret_key': random_secret()})


def deploy():
    """Run all the jobs in nomad."""

    consul.set_kv('liquid_domain', config.liquid_domain)
    consul.set_kv('liquid_debug', config.liquid_debug)

    vault.ensure_engine()

    vault_secret_keys = [
        'liquid/core.django',
        'hoover/search.django',
        'authdemo/auth.django',
    ]

    for path in vault_secret_keys:
        ensure_secret_key(path)

    jobs = [(job, get_job(path)) for job, path in config.jobs]

    for name, settings in config.collections.items():
        job = get_collection_job(name, settings)
        jobs.append((f'collection-{name}', job))
        ensure_secret_key(f'collections/{name}/snoop.django')

    for job, hcl in jobs:
        log.info('Starting %s...', job)
        nomad.run(hcl)

    for app in core_auth_apps:
        log.info('Auth %s -> %s', app['name'], app['callback'])
        cmd = ['./manage.py', 'createoauth2app', app['name'], app['callback']]
        containers = docker.containers([('liquid_task', 'liquid-core')])
        container_id = first(containers, 'containers')
        docker_exec_cmd = ['docker', 'exec', '-it', container_id] + cmd
        tokens = json.loads(run(docker_exec_cmd, shell=False))
        vault.set(app['vault_path'], tokens)


def halt():
    """Stop all the jobs in nomad."""

    jobs = [j for j, _ in config.jobs]
    jobs.extend(f'collection-{name}' for name in config.collections)
    for job in jobs:
        log.info('Stopping %s...', job)
        nomad.stop(job)


def gc():
    """Stop collections jobs that are no longer declared in the ini file."""

    nomad_jobs = nomad.jobs()

    for job in nomad_jobs:
        if job['ID'].startswith('collection-'):
            collection_name = job['ID'][len('collection-'):]
            if collection_name not in config.collections and job['Status'] == 'running':
                log.info('Stopping %s...', job['ID'])
                nomad.stop(job['ID'])


def nomad_address():
    """Print the nomad address."""

    print(nomad.get_address())


def alloc(job, group):
    """Print the ID of the current allocation of the job and group.

    :param job: the job identifier
    :param group: the group identifier
    """

    allocs = nomad.job_allocations(job)
    running = [
        a['ID'] for a in allocs
        if a['ClientStatus'] == 'running' and a['TaskGroup'] == group
    ]
    print(first(running, 'running allocations'))


def initcollection(name):
    """Initialize collection with given name.

    Create the snoop database, create the search index, run dispatcher, add collection
    to search.

    :param name: the collection name
    """

    if name not in config.collections:
        raise RuntimeError('Collection %s does not exist in the liquid.ini file.', name)

    if name in get_search_collections():
        log.info(f'Collection "{name}" was already initialized.')
        return

    shell(f'snoop-{name}-api', './manage.py', 'initcollection')

    shell(
        'hoover-search',
        './manage.py', 'addcollection', name,
        '--index', name,
        f'http://{nomad.get_address()}:8765/{name}/collection/json',
        '--public',
    )


def purge(force=False):
    """Purge collections no longer declared in the ini file

    Remove the residual data and the hoover search index for collections that are no
    longer declared in the ini file.
    """

    to_purge = get_collections_to_purge()
    if not to_purge:
        print('No collections to purge.')
        return

    if to_purge:
        print('The following collections will be purged:')
        for coll in to_purge:
            print(' - ', coll)
        print('')

    if not force:
        confirm = None
        while confirm not in ['y', 'n']:
            print('Please confirm collections purge [y/n]: ', end='')
            confirm = input().lower()
            if confirm not in ['y', 'n']:
                print(f'Invalid input: {confirm}')

    if force or confirm == 'y':
        for coll in to_purge:
            print(f'Purging collection {coll}...')
            purge_collection(coll)
    else:
        print('No collections will be purged')


def shell(name, *args):
    """Open a shell in a docker container tagged with liquid_task=`name`"""

    docker.shell(name, *args)


def initializevault():
    """ Initializes the Vault. """

    resp = vault.init()
    print('Keys:', resp['keys'])
    print('Root token:', resp['root_token'])


def unsealvault():
    """ Unseal the Vault. """

    key = config.vault_key or getpass()
    status = vault.unseal(key)
    print('Vault is now', 'sealed' if status['sealed'] else 'unsealed')
