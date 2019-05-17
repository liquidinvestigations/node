import logging
import os
from contextlib import contextmanager

log = logging.getLogger(__name__)


def first(items, name_plural='items'):
    assert items, f"No {name_plural} found"

    if len(items) > 1:
        log.warning(
            f"Found multiple {name_plural}: %r, choosing the first one",
            items,
        )

    return items[0]


@contextmanager
def change_dir(path):
    current_dir = os.getcwd()
    try:
        os.chdir(str(path))
        yield path
    finally:
        os.chdir(current_dir)
