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

DEBUG = os.environ.get('DEBUG', '').lower() in ['on', 'true']
LOG_LEVEL = logging.DEBUG if DEBUG else logging.INFO

log = logging.getLogger(__name__)
log.setLevel(LOG_LEVEL)

JOBS = [
    (job, Path(f'{job}.nomad'))
    for job in ['hoover', 'hoover-ui', 'liquid']
]

config = configparser.ConfigParser()
config.read('liquid.ini')


if 'extra_jobs' in config:
    for job, path in config['extra_jobs'].items():
        JOBS.append((job, Path(path)))


def get_collections():
    sections = []
    for section_name in config:
        if ':' not in section_name:
            continue

        (label, collection_name) = section_name.split(':')
        if label == 'collection' and collection_name:
            sections.append((collection_name, config[section_name]))

    return sections


def get_config(env_key, ini_path, default=None):
    if env_key and os.environ.get(env_key):
        return os.environ[env_key]

    (section_name, key) = ini_path.split('.')
    if section_name in config and key in config[section_name]:
        return config[section_name][key]

    return default


nomad_url = get_config(
    'NOMAD_URL',
    'cluster.nomad_url',
    'http://127.0.0.1:4646',
)

consul_url = get_config(
    'CONSUL_URL',
    'cluster.consul_url',
    'http://127.0.0.1:8500',
)

liquid_domain = get_config(
    'LIQUID_DOMAIN',
    'liquid.domain',
    'localhost',
)

liquid_debug = get_config(
    'LIQUID_DEBUG',
    'liquid.debug',
    '',
)

liquid_volumes = get_config(
    'LIQUID_VOLUMES',
    'liquid.volumes',
    str(Path(__file__).parent.resolve() / 'volumes'),
)

liquid_collections = get_config(
    'LIQUID_COLLECTIONS',
    'liquid.collections',
    str(Path(__file__).parent.resolve() / 'collections'),
)


def run(cmd):
    log.debug("+ %s", cmd)
    return subprocess.check_output(cmd, shell=True).decode('latin1')


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
nomad = Nomad(nomad_url)
consul = Consul(consul_url)


def first(items, name_plural='items'):
    assert items, f"No {name_plural} found"

    if len(items) > 1:
        log.warning(
            f"Found multiple {name_plural}: %r, choosing the first one",
            items,
        )

    return items[0]


def shell(name, *args):
    """
    Open a shell in a docker container tagged with liquid_task=`name`
    """
    containers = docker.containers([('liquid_task', name)])
    container_id = first(containers, 'containers')
    docker_exec_cmd = ['docker', 'exec', '-it', container_id] + list(args or ['bash'])
    run_fg(docker_exec_cmd, shell=False)


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


def nomad_address():
    """
    Print the nomad server's address.
    """
    members = [m['Addr'] for m in nomad.agent_members()]
    print(first(members, 'members'))


def set_collection_defaults(name, settings):
    settings['name'] = name
    settings.setdefault('workers', 2)


def set_volumes_paths(substitutions={}):
    substitutions['liquid_volumes'] = liquid_volumes
    substitutions['liquid_collections'] = liquid_collections
    return substitutions


def get_collection_job(name, settings):
    substitutions = copy(settings)
    set_collection_defaults(name, substitutions)

    return get_job(Path('collection.nomad'), substitutions)


def get_job(hcl_path, substitutions={}):
    with hcl_path.open() as job_file:
        template = Template(job_file.read())

    return template.safe_substitute(set_volumes_paths(substitutions))


def deploy():
    """ Run all the jobs in nomad. """

    consul.set_kv('liquid_domain', liquid_domain)
    consul.set_kv('liquid_debug', liquid_debug)

    jobs = [(job, get_job(path)) for job, path in JOBS]
    jobs.extend([(f'collection-{name}', get_collection_job(name, settings))
                 for name, settings in get_collections()])

    for job, hcl in jobs:
        log.info('Starting %s...', job)
        nomad.run(hcl)


def halt():
    """ Stop all the jobs in nomad. """

    jobs = [j for j, _ in JOBS] + [f'collection-{name}' for name, _ in get_collections()]
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
        halt,
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
