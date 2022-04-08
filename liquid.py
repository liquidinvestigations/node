#!/usr/bin/env python3
import sys
import colorlog
import logging
import click


level = logging.DEBUG
handler = colorlog.StreamHandler()
handler.setLevel(level)
handler.setFormatter(colorlog.ColoredFormatter(
    '%(asctime)s %(log_color)s%(levelname)8s %(message)s'))
logging.basicConfig(
    handlers=[handler],
    level=level,
    datefmt='%Y-%m-%d %H:%M:%S',
)

from liquid_node.configuration import config
from liquid_node.commands import liquid_commands
from liquid_node.backup import backup_commands


log = logging.getLogger(__name__)

cli = click.CommandCollection(sources=[liquid_commands, backup_commands])

if __name__ == '__main__':
    level = logging.DEBUG if config.liquid_debug else logging.INFO
    handler.setLevel(level)

    try:
        cli()
    except Exception as e:
        log.exception(e)
        sys.exit(66)
