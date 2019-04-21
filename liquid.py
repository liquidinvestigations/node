#!/usr/bin/env python3

""" Manage liquid on a nomad cluster. """

import os
import sys
import logging
import argparse
from liquid_node import commands
from urllib.error import HTTPError


DEBUG = os.environ.get('DEBUG', '').lower() in ['on', 'true']
LOG_LEVEL = logging.DEBUG if DEBUG else logging.INFO

log = logging.getLogger(__name__)
log.setLevel(LOG_LEVEL)


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
        commands.shell,
        commands.alloc,
        commands.nomad_address,
        commands.deploy,
        commands.gc,
        commands.halt,
        commands.initcollection,
        commands.purge,
        commands.initializevault,
    ])
    (options, extra_args) = parser.parse_known_args()
    options.cmd(*extra_args)


if __name__ == '__main__':
    logging.basicConfig(
        level=LOG_LEVEL,
        format='%(asctime)s %(levelname)s %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
    )

    try:
        main()
    except HTTPError as e:
        log.exception("HTTP Error %r: %r", e, e.file.read())
        sys.exit(1)
