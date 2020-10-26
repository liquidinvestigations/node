from pathlib import Path
from .process import run, run_fg


class Docker:

    def containers(self, labels=[]):
        label_args = ' '.join(f'-f label={k}={v}' for k, v in labels)
        out = run(f'docker ps -q {label_args}')
        return out.split()

    def exec_command(self, name, *args, tty=False):
        """Prepare and return the command to run in a user shell.

        :param name: the value of the liquid_task tag
        :param tty: if true, instruct docker to allocate a pseudo-TTY and keep stdin open
        """
        from .configuration import config

        [job, task] = name.split(':')

        if config.cluster_root_path:
            # run the exec binary in the source dir
            nomad_exec = str((Path(config.cluster_root_path) / 'nomad-exec').resolve())
            exec_cmd = [nomad_exec]
            if tty:
                exec_cmd += ['-t']
            exec_cmd += [name, '--'] + list(args or (['bash'] if tty else []))
            return exec_cmd

        else:
            # the old way: run through the `cluster` docker container
            docker_exec_cmd = ['docker', 'exec', '-i']
            if tty:
                docker_exec_cmd += ['-t']
            docker_exec_cmd += ['cluster', './cluster.py', 'nomad-exec']
            if tty:
                docker_exec_cmd += ['-t']
            docker_exec_cmd += [name, '--'] + list(args or (['bash'] if tty else []))
            return docker_exec_cmd

    def exec_command_str(self, *args, **kwargs):
        return " ".join(self.exec_command(*args, **kwargs))

    def shell(self, name, *args):
        """Run the given command in a docker container named JOB:TASK.

        The command output is redirected to the standard output and a tty is opened.
        """
        run_fg(self.exec_command(name, *args, tty=True), shell=False)

    def exec_(self, name, *args):
        """Run the given command in a docker container named JOB:TASK.

        The command standard output is returned as a decoded ascii string for parsing.
        """
        return run(self.exec_command(name, *args), shell=False)


docker = Docker()
