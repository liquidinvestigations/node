#!/usr/bin/env python3

"""
A tool for quick-and-dirty actions on a nomad liquid cluster.

https://half-life.fandom.com/wiki/Crowbar
"""

import os
import logging
import subprocess
from urllib.request import urlopen
import json
import argparse

DEBUG = os.environ.get('DEBUG', '').lower() in ['on', 'true']
LOG_LEVEL = logging.DEBUG if DEBUG else logging.INFO

log = logging.getLogger(__name__)
log.setLevel(LOG_LEVEL)


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


class Nomad:
    def __init__(self, api='http://127.0.0.1:4646'):
        self.api = api

    def get(self, url):
        full_url = f'{self.api}/v1/{url}'
        log.debug('nomad api: GET %r', full_url)
        with urlopen(full_url) as resp:
            body = json.load(resp)
            log.debug('response: %r', body)
            return body


docker = Docker()
nomad = Nomad()


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
    id = first(containers, 'containers')
    docker_exec_cmd = ['docker', 'exec', '-it', id] + list(args or ['bash'])
    run_fg(docker_exec_cmd, shell=False)


def alloc(name):
    """
    Print the ID of the current allocation of the job `name`.
    """
    allocs = nomad.get(f'job/{name}/allocations')
    running = [a['ID'] for a in allocs if a['ClientStatus'] == 'running']
    print(first(running, 'running allocations'))


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
