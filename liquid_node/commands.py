from time import time, sleep
import logging
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


def wait_for_service_health_checks(health_checks):
    """Waits health checks to become green for green_count times in a row. """

    def get_failed_checks():
        """Generates a list of (service, check, status)
        for all failing checks after checking with Consul"""

        consul_status = {}
        for service in health_checks:
            for s in consul.get(f'/health/checks/{service}'):
                key = service, s['Name']
                if key in consul_status:
                    consul_status[key] = 'appears twice. Maybe halt, restart Consul and try again?'
                    continue
                consul_status[key] = s['Status']

        for service, checks in health_checks.items():
            for check in checks:
                status = consul_status.get((service, check), 'missing')
                if status != 'passing':
                    yield service, check, status

    services = sorted(health_checks.keys())
    log.info(f"Waiting for health checks on {services}")

    t0 = time()
    greens = 0
    timeout = t0 + config.wait_max + config.wait_interval * config.wait_green_count
    while time() < timeout:
        sleep(config.wait_interval)
        failed = sorted(get_failed_checks())

        if failed:
            greens = 0
        else:
            greens += 1

        if greens >= config.wait_green_count:
            log.info(f"Checks green {services} after {time() - t0:.02f}s")
            return

        # No chance to get enough greens
        no_chance_timestamp = timeout - config.wait_interval * config.wait_green_count
        if greens == 0 and time() >= no_chance_timestamp:
            break

        failed_text = ''
        for service, check, status in failed:
            failed_text += f'\n - {service}: check "{check}" is {status}'
        if failed:
            failed_text += '\n'
        log.debug(f'greens = {greens}, failed = {len(failed)}{failed_text}')

    msg = f'Checks are failing after {time() - t0:.02f}s: \n - {failed_text}'
    raise RuntimeError(msg)


def deploy():
    """Run all the jobs in nomad."""

    consul.set_kv('liquid_domain', config.liquid_domain)
    consul.set_kv('liquid_debug', 'true' if config.liquid_debug else 'false')

    vault.ensure_engine()

    vault_secret_keys = [
        'liquid/core.django',
        'hoover/search.django',
        'authdemo/auth.django',
        'nextcloud/nextcloud.admin',
        'nextcloud/nextcloud.pg',
    ]

    for path in vault_secret_keys:
        ensure_secret_key(path)

    def start(job, hcl):
        log.info('Starting %s...', job)
        nomad.run(hcl)
        job_checks = {}
        for service, checks in nomad.get_health_checks(hcl):
            if not checks:
                log.warn(f'service {service} has no health checks')
                continue
            job_checks[service] = checks
        return job_checks

    jobs = [(job, get_job(path)) for job, path in config.jobs]

    for name, settings in config.collections.items():
        migrate_job = get_collection_job(name, settings, 'collection-migrate.nomad')
        jobs.append((f'collection-{name}-migrate', migrate_job))
        job = get_collection_job(name, settings)
        jobs.append((f'collection-{name}', job))
        ensure_secret_key(f'collections/{name}/snoop.django')

    # Start liquid-core in order to setup the auth
    liquid_checks = start('liquid', dict(jobs)['liquid'])
    wait_for_service_health_checks({'core': liquid_checks['core']})

    for app in core_auth_apps:
        log.info('Auth %s -> %s', app['name'], app['callback'])
        cmd = ['./manage.py', 'createoauth2app', app['name'], app['callback']]
        containers = docker.containers([('liquid_task', 'liquid-core')])
        container_id = first(containers, 'liquid-core containers')
        docker_exec_cmd = ['docker', 'exec', container_id] + cmd
        tokens = json.loads(run(docker_exec_cmd, shell=False))
        vault.set(app['vault_path'], tokens)

    health_checks = {}
    for job, hcl in jobs:
        job_checks = start(job, hcl)
        health_checks.update(job_checks)

    # Wait for everything else
    wait_for_service_health_checks(health_checks)

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
        log.warning(f'Collection "{name}" was already initialized.')
        return

    docker.exec_(f'snoop-{name}-api', './manage.py', 'initcollection')

    docker.exec_(
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


def dockerexec(name, *args):
    """Run `docker exec` in a container tagged with liquid_task=`name`"""

    docker.exec_(name, *args)
