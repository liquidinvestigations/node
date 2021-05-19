from time import sleep
import base64
import os
import sys
import logging
from importlib import import_module
from contextlib import contextmanager


log = logging.getLogger(__name__)


@contextmanager
def stderr_muted():
    """
    A contextmanager that enables muting stderr including subprocesses.

    It sets the stderr at file descriptor level to make sure subprocesses are also affected.
    """
    stderr = sys.stderr
    stderr_fd = stderr.fileno()
    with os.fdopen(os.dup(stderr_fd), 'wb') as stderr_orig:
        stderr.flush()
        with open(os.devnull, 'wb') as to_file:
            os.dup2(to_file.fileno(), stderr_fd)
        try:
            yield stderr
        finally:
            stderr.flush()
            os.dup2(stderr_orig.fileno(), stderr_fd)


def first(items, name_plural='items'):
    assert items, f"No {name_plural} found"

    if len(items) > 1:
        log.warning(
            f"Found multiple {name_plural}: %r, choosing the first one",
            items,
        )

    return items[0]


def import_string(dotted_path):
    """
    Import a dotted module path and return the attribute/class designated by the
    last name in the path. Raise ImportError if the import failed.
    """
    # Borrowed from `django.utils.module_loading.import_string`
    try:
        module_path, class_name = dotted_path.rsplit('.', 1)
    except ValueError as err:
        msg = f"{dotted_path} doesn't look like a module path"
        raise ImportError(msg) from err

    module = import_module(module_path)

    try:
        return getattr(module, class_name)
    except AttributeError as err:
        msg = f"Module {module_path!r} does not define {class_name!r}"
        raise ImportError(msg) from err


def retry(count=4, wait_sec=5, exp=2):
    def _retry(f):
        def wrapper(*args, **kwargs):
            current_wait = wait_sec
            for i in range(count):
                try:
                    if i == count - 1:
                        return f(*args, **kwargs)
                    else:
                        with stderr_muted():
                            return f(*args, **kwargs)
                except Exception as e:
                    if i == count - 1:
                        log.exception(e)
                        raise

                    log.warning("%s(): #%s/%s retrying in %s sec",
                                f.__qualname__,
                                i + 1, count, current_wait)
                    sleep(current_wait)
                    current_wait = int(current_wait * exp)
                    continue
        return wrapper

    return _retry


def random_secret(bits=256):
    """ Generate a crypto-quality 256-bit random string. """
    return str(base64.b16encode(os.urandom(int(bits / 8))), 'latin1').lower()
