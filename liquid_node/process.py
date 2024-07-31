import logging
import subprocess
import time


log = logging.getLogger(__name__)


def run(cmd, echo=True, **kwargs):
    """Run the given command in a subprocess and return the captured output."""

    if echo:
        log.debug("+ %s", cmd)
    kwargs.setdefault('shell', False)
    time.sleep(0.1)
    output = subprocess.check_output(cmd, **kwargs).decode('latin1')
    time.sleep(0.1)
    return output


def run_fg(cmd, echo=True, **kwargs):
    """Run the given command in a subprocess.

    The command output is redirected to the standard output and a tty is opened.
    """

    if echo:
        log.debug("+ %s", cmd)
    kwargs.setdefault('shell', True)
    kwargs.setdefault('check', True)
    subprocess.run(cmd, **kwargs)
