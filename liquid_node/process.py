import logging
import subprocess


log = logging.getLogger(__name__)


def run(cmd, **kwargs):
    """Run the given command in a subprocess and return the captured output."""

    log.debug("+ %s", cmd)
    kwargs.setdefault('shell', False)
    return subprocess.check_output(cmd, **kwargs).decode('latin1')


def run_fg(cmd, **kwargs):
    """Run the given command in a subprocess.

    The command output is redirected to the standard output and a tty is opened.
    """

    log.debug("+ %s", cmd)
    kwargs.setdefault('shell', True)
    kwargs.setdefault('check', True)
    subprocess.run(cmd, **kwargs)
