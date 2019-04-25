import logging
import subprocess


log = logging.getLogger(__name__)


def run(cmd, **kwargs):
    log.debug("+ %s", cmd)
    kwargs.setdefault('shell', True)
    kwargs.setdefault('stderr', subprocess.STDOUT)
    return subprocess.check_output(cmd, **kwargs).decode('latin1')


def run_fg(cmd, **kwargs):
    log.debug("+ %s", cmd)
    kwargs.setdefault('shell', True)
    subprocess.check_call(cmd, **kwargs)

def run_shell(name, *args):
    from .docker import docker
    run_fg(docker.exec_command(name, *args, tty=True), shell=False)
