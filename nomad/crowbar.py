#!/usr/bin/env python3

import subprocess
import argparse


def run(cmd):
    return subprocess.check_output(cmd, shell=True).decode('latin1')


def run_fg(cmd, **kwargs):
    kwargs.setdefault('shell', True)
    subprocess.check_call(cmd, **kwargs)

class Docker:
    def containers(self, labels=[]):
        label_args = ' '.join(f'-f label={k}={v}' for k, v in labels)
        out = run(f'docker ps -q {label_args}')
        return out.split()

docker = Docker()


def shell(name, *args):
    containers = docker.containers([('liquid_task', name)])
    assert len(containers) == 1, \
        f"Expected exactly one container, got {containers!r}"
    [id] = containers
    docker_exec_cmd = ['docker', 'exec', '-it', id] + list(args or ['bash'])
    run_fg(docker_exec_cmd, shell=False)


class SubcommandParser(argparse.ArgumentParser):

    def add_subcommands(self, name, subcommands):
        subcommands_map = {c.__name__: c for c in subcommands}

        class SubcommandAction(argparse.Action):
            def __call__(self, parser, namespace, values, option_string=None):
                setattr(namespace, name, subcommands_map[values])

        self.add_argument(name,
            choices=[c.__name__ for c in subcommands],
            action=SubcommandAction,
        )


def main():
    parser = SubcommandParser()
    parser.add_subcommands('cmd', [
        shell,
    ])
    (options, extra_args) = parser.parse_known_args()
    options.cmd(*extra_args)


if __name__ == '__main__':
    main()
