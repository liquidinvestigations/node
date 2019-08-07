#!/usr/bin/env python3

""" Manage liquid on a nomad cluster. """

import sys
import logging
import argparse
from liquid_node import commands
from urllib.error import HTTPError


import colorlog

log = logging.getLogger(__name__)


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
        commands.dockerexec,
        commands.alloc,
        commands.nomad_address,
        commands.deploy,
        commands.resources,
        commands.collectionsgc,
        commands.nomadgc,
        commands.halt,
        commands.initcollection,
        commands.deletecollection,
        commands.importcollection,
        commands.purge,
        commands.getsecret,
        commands.importfromdockersetup,
    ])
    (options, extra_args) = parser.parse_known_args()
    options.cmd(*extra_args)


if __name__ == '__main__':
    from liquid_node.configuration import config
    level = logging.DEBUG if config.liquid_debug else logging.INFO
    handler = colorlog.StreamHandler()
    handler.setLevel(level)
    handler.setFormatter(colorlog.ColoredFormatter(
        '%(asctime)s %(log_color)s%(levelname)8s %(message)s'))
    logging.basicConfig(
        handlers=[handler],
        level=level,
        datefmt='%Y-%m-%d %H:%M:%S',
    )

    try:
        main()
    except HTTPError as e:
        log.exception("HTTP Error %r: %r", e, e.file.read())
        sys.exit(1)
