#!/usr/bin/env python3

""" Manage liquid on a nomad cluster. """

import os
import logging
import subprocess
from urllib.request import Request, urlopen
from urllib.error import HTTPError
import json
import argparse
from pathlib import Path
import configparser
from string import Template
from copy import copy
from subprocess import CalledProcessError
import sys
import shutil
from collections import OrderedDict


DEBUG = os.environ.get('DEBUG', '').lower() in ['on', 'true']
LOG_LEVEL = logging.DEBUG if DEBUG else logging.INFO

log = logging.getLogger(__name__)
log.setLevel(LOG_LEVEL)


class Configuration:

    def __init__(self):
        self.jobs = [
            (job, Path(f'{job}.nomad'))
            for job in ['hoover', 'hoover-ui', 'liquid']
        ]

        self.ini = configparser.ConfigParser()
        self.ini.read('liquid.ini')

        self.nomad_url = self.get(
            'NOMAD_URL',
            'cluster.nomad_url',
            'http://127.0.0.1:4646',
        )

        self.consul_url = self.get(
            'CONSUL_URL',
            'cluster.consul_url',
            'http://127.0.0.1:8500',
        )

        self.liquid_domain = self.get(
            'LIQUID_DOMAIN',
            'liquid.domain',
            'localhost',
        )

        self.liquid_debug = self.get(
            'LIQUID_DEBUG',
            'liquid.debug',
            '',
        )

        self.mount_local_repos = 'false' != self.get(
            'LIQUID_MOUNT_LOCAL_REPOS',
            'liquid.mount_local_repos',
            'false',
        )

        self.hoover_repos_path = self.get(
            'LIQUID_HOOVER_REPOS_PATH',
            'liquid.hoover_repos_path',
            None,
        )

        self.liquidinvestigations_repos_path = self.get(
            'LIQUID_LIQUIDINVESTIGATIONS_REPOS_PATH',
            'liquid.liquidinvestigations_repos_path',
            None,
        )

        self.liquid_volumes = self.get(
            'LIQUID_VOLUMES',
            'liquid.volumes',
            str(Path(__file__).parent.resolve() / 'volumes'),
        )

        self.liquid_collections = self.get(
            'LIQUID_COLLECTIONS',
            'liquid.collections',
            str(Path(__file__).parent.resolve() / 'collections'),
        )

        self.liquid_http_port = self.get(
            'LIQUID_HTTP_PORT',
            'liquid.http_port',
            '80',
        )

        self.collections = OrderedDict()
        for key in self.ini:
            if ':' not in key:
                continue

            (cls, name) = key.split(':')

            if cls == 'collection':
                Configuration._validate_collection_name(name)
                self.collections[name] = self.ini[key]

            elif cls == 'job':
                job_config = self.ini[key]
                self.jobs.append((name, Path(job_config['template'])))

    def get(self, env_key, ini_path, default=None):
        if env_key and os.environ.get(env_key):
            return os.environ[env_key]

        (section_name, key) = ini_path.split('.')
        if section_name in self.ini and key in self.ini[section_name]:
            return self.ini[section_name][key]

        return default

    @classmethod
    def _validate_collection_name(self, name):
        if not name.islower():
            raise ValueError(f'''Invalid collection name "{name}"!

Collection names must start with lower case letters and must contain only
lower case letters and digits.
''')


config = Configuration()


def run(cmd, **kwargs):
    log.debug("+ %s", cmd)
    kwargs.setdefault('shell', True)
    kwargs.setdefault('stderr', subprocess.STDOUT)
    return subprocess.check_output(cmd, **kwargs).decode('latin1')


def run_fg(cmd, **kwargs):
    kwargs.setdefault('shell', True)
    subprocess.check_call(cmd, **kwargs)


class Docker:

    def containers(self, labels=[]):
        label_args = ' '.join(f'-f label={k}={v}' for k, v in labels)
        out = run(f'docker ps -q {label_args}')
        return out.split()


class JsonApi:

    def __init__(self, endpoint):
        self.endpoint = endpoint

    def request(self, method, url, data=None):
        req_url = f'{self.endpoint}{url}'
        req_headers = {}
        req_body = None

        if data is not None:
            if isinstance(data, bytes):
                req_body = data

            else:
                req_headers['Content-Type'] = 'application/json'
                req_body = json.dumps(data).encode('utf8')

        log.debug('%s %r %r', method, req_url, data)
        req = Request(
            req_url,
            req_body,
            req_headers,
            method=method,
        )

        try:
            with urlopen(req) as res:
                res_body = json.load(res)
                log.debug('response: %r', res_body)
                return res_body

        except HTTPError as e:
            log.error("Error %r: %r", e, e.file.read())
            raise

    def get(self, url):
        return self.request('GET', url)

    def post(self, url, data):
        return self.request('POST', url, data)

    def put(self, url, data):
        return self.request('PUT', url, data)

    def delete(self, url):
        return self.request('DELETE', url)


class Nomad(JsonApi):

    def __init__(self, endpoint):
        super().__init__(endpoint + '/v1/')

    def run(self, hcl):
        spec = self.post(f'jobs/parse', {'JobHCL': hcl})
        return self.post(f'jobs', {'job': spec})

    def jobs(self):
        return nomad.get(f'jobs')

    def job_allocations(self, job):
        return nomad.get(f'job/{job}/allocations')

    def agent_members(self):
        return self.get('agent/members')['Members']

    def stop(self, job):
        return self.delete(f'job/{job}')


class Consul(JsonApi):

    def __init__(self, endpoint):
        super().__init__(endpoint + '/v1/')

    def set_kv(self, key, value):
        assert self.put(f'kv/{key}', value.encode('latin1'))


docker = Docker()
nomad = Nomad(config.nomad_url)
consul = Consul(config.consul_url)


def first(items, name_plural='items'):
    assert items, f"No {name_plural} found"

    if len(items) > 1:
        log.warning(
            f"Found multiple {name_plural}: %r, choosing the first one",
            items,
        )

    return items[0]


def docker_exec_command(name, *args, tty=False):
    """Prepare and return the command to run in a docker container tagged with
    liquid_task=`name`

    :param name: the value of the liquid_task tag
    :param tty: if true, instruct docker to allocate a pseudo-TTY and keep stdin open
    """
    containers = docker.containers([('liquid_task', name)])
    container_id = first(containers, 'containers')

    docker_exec_cmd = ['docker', 'exec']
    if tty:
        docker_exec_cmd += ['-it']
    docker_exec_cmd += [container_id] + list(args or (['bash'] if tty else []))

    return docker_exec_cmd


def shell(name, *args):
    """Open a shell in a docker container tagged with liquid_task=`name`"""
    run_fg(docker_exec_command(name, *args, tty=True), shell=False)


def alloc(job, group):
    """
    Print the ID of the current allocation of the job and group.
    """
    allocs = nomad.job_allocations(job)
    running = [
        a['ID'] for a in allocs
        if a['ClientStatus'] == 'running'
            and a['TaskGroup'] == group
    ]
    print(first(running, 'running allocations'))


def get_search_collections():
    try:
        return run(docker_exec_command('hoover-search', './manage.py', 'listcollections'),
                   shell=False).split()
    except CalledProcessError as e:
        print(e.output.decode('latin1'), file=sys.stderr)
        raise


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

    shell('hoover-search', './manage.py', 'addcollection', name, '--index',
          name, f'{get_nomad_address()}:8765/{name}/collection/json', '--public')


def get_nomad_address():
    """
    Print the nomad server's address.
    """
    members = [m['Addr'] for m in nomad.agent_members()]
    return first(members, 'members')


def nomad_address():
    print(get_nomad_address())


def set_collection_defaults(name, settings):
    settings['name'] = name
    settings.setdefault('workers', '1')


def set_volumes_paths(substitutions={}):
    substitutions['liquid_volumes'] = config.liquid_volumes
    substitutions['liquid_collections'] = config.liquid_collections
    substitutions['liquid_http_port'] = config.liquid_http_port

    repos_path = os.path.join(os.path.realpath(os.path.dirname(__file__)), 'repos')
    repos = {
        'snoop2': {
            'org': 'hoover',
            'local': os.path.join(repos_path, 'hoover'),
            'target': '/opt/hoover/snoop'
        },
        'search': {
            'org': 'hoover',
            'local': os.path.join(repos_path, 'hoover'),
            'target': '/opt/hoover/search'
        },
        'core': {
            'org': 'liquidinvestigations',
            'local': os.path.join(repos_path, 'liquidinvestigations'),
            'target': '/app'
        }
    }

    if config.hoover_repos_path:
        repos['snoop2']['local'] = os.path.abspath(config.hoover_repos_path)
        repos['search']['local'] = os.path.abspath(config.hoover_repos_path)
    if config.liquidinvestigations_repos_path:
        repos['core']['local'] = os.path.abspath(config.liquidinvestigations_repos_path)

    for repo, repo_config in repos.items():
        repo_path = os.path.join(repo_config['local'], repo)

        repo_volume_line = (f"\"{repo_path}:{repo_config['target']}\",\n")
        key = f"{repo_config['org']}_{repo}_repo"

        if config.mount_local_repos:
            substitutions[key] = repo_volume_line
        else:
            substitutions[key] = ''

    return substitutions


def get_collection_job(name, settings):
    substitutions = copy(settings)
    set_collection_defaults(name, substitutions)

    return get_job(Path('collection.nomad'), substitutions)


def get_job(hcl_path, substitutions={}):
    with hcl_path.open() as job_file:
        template = Template(job_file.read())

    return template.safe_substitute(set_volumes_paths(substitutions))


def gc():
    """Stop collections jobs that are no longer declared in the ini file."""

    nomad_jobs = nomad.jobs()

    for job in nomad_jobs:
        if job['ID'].startswith('collection-'):
            collection_name = job['ID'][len('collection-'):]
            if collection_name not in config.collections and job['Status'] == 'running':
                log.info('Stopping %s...', job['ID'])
                nomad.stop(job['ID'])


def get_collections_to_purge():
    """Returns a set of collections to purge."""

    ini_collections = set(config.collections.keys())

    collections_dir = Path(config.liquid_volumes) / 'collections'
    volumes = set([subdir.name for subdir in collections_dir.iterdir() if subdir.is_dir()])

    return volumes - ini_collections


def purge_collection(name):
    """Purge data for the given collection, remove it from hoover search."""

    if name in get_search_collections():
        shell('hoover-search', './manage.py', 'removecollection', name)
        log.info(f'Collection {name} was removed from hoover search.')

    collection_volume = Path(config.liquid_volumes) / 'collections' / name
    if collection_volume.is_dir():
        shutil.rmtree(collection_volume)
    log.info(f'Collection {name} data was purged.')


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


def deploy():
    """ Run all the jobs in nomad. """

    consul.set_kv('liquid_domain', config.liquid_domain)
    consul.set_kv('liquid_debug', config.liquid_debug)

    jobs = [(job, get_job(path)) for job, path in config.jobs]
    jobs.extend(
        (f'collection-{name}', get_collection_job(name, settings))
        for name, settings in config.collections.items()
    )

    for job, hcl in jobs:
        log.info('Starting %s...', job)
        nomad.run(hcl)


def halt():
    """ Stop all the jobs in nomad. """

    jobs = [j for j, _ in config.jobs]
    jobs.extend(f'collection-{name}' for name in config.collections)
    for job in jobs:
        log.info('Stopping %s...', job)
        nomad.stop(job)


class SubcommandParser(argparse.ArgumentParser):

    def add_subcommands(self, name, subcommands):
        subcommands_map = {c.__name__: c for c in subcommands}

        class SubcommandAction(argparse.Action):
            def __call__(self, parser, namespace, values, option_string=None):
                setattr(namespace, name, subcommands_map[values])

        self.add_argument(
            name,
            choices=[c.__name__ for c in subcommands],
            action=SubcommandAction,
        )


def main():
    parser = SubcommandParser(description=__doc__)
    parser.add_subcommands('cmd', [
        shell,
        alloc,
        nomad_address,
        deploy,
        gc,
        halt,
        initcollection,
        purge,
    ])
    (options, extra_args) = parser.parse_known_args()
    options.cmd(*extra_args)


if __name__ == '__main__':
    logging.basicConfig(
        level=LOG_LEVEL,
        format='%(asctime)s %(levelname)s %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
    )
    main()
