from .process import run
from .util import first
from liquid_node.process import run_fg


class Docker:

    def containers(self, labels=[]):
        label_args = ' '.join(f'-f label={k}={v}' for k, v in labels)
        out = run(f'docker ps -q {label_args}')
        return out.split()

    def exec_command(self, name, *args, interactive=False, tty=False):
        """Prepare and return the command to run in a docker container tagged with
        liquid_task=`name`
        :param name: the value of the liquid_task tag
        :param tty: if true, instruct docker to allocate a pseudo-TTY
        :param interactive: if true docker will keep STDIN open
        """

        docker_exec_cmd = ['docker', 'exec']

        containers = self.containers([('liquid_task', name)])
        container_id = first(containers, f'{name} containers')

        if tty:
            docker_exec_cmd += ['-t']
        if interactive:
            docker_exec_cmd += ['-i']
        docker_exec_cmd += [container_id] + list(args or (['bash'] if (tty and interactive) else []))
        return docker_exec_cmd

    def shell(self, name, *args, stdin=None, stdout=None):
        """Run the given command in a docker container tagged with liquid_task=`name`.

        The command output is redirected to the standard output and a tty is opened.
        """
        run_fg(self.exec_command(name, *args, tty=True, interactive=True),
               stdin=stdin, stdout=stdout, shell=False)

    def exec_(self, name, *args, interactive=False, tty=False, stdin=None, stdout=None):
        run_fg(self.exec_command(name, *args, interactive=interactive, tty=tty),
               stdin=stdin, stdout=stdout, shell=False)


docker = Docker()
