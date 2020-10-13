import os
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

        exec_path = os.path.join(config.cluster_root_path, 'nomad-exec')
        exec_cmd = [exec_path]

        if tty:
            exec_cmd += ['-t']

        exec_cmd += [name, '--'] + list(args or (['bash'] if tty else []))
        return exec_cmd

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
