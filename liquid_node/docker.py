from .process import run
from .util import first
from liquid_node.process import run_fg


class Docker:

    def containers(self, labels=[]):
        label_args = ' '.join(f'-f label={k}={v}' for k, v in labels)
        out = run(f'docker ps -q {label_args}')
        return out.split()

    def exec_command(self, *args, tty=False):
        """Prepare and return the command to run in a docker container tagged with
        liquid_task=`name`.
        you can give the same flags to the command as to docker exec, at the beginning
        of your command. The first argument, which doesn't start with '-' is interpreted
        as the container name.

        :param name: the value of the liquid_task tag
        """
        additional_args = []
        name = ''
        docker_exec_cmd = ['docker', 'exec']
        for arg in args:
            if not name:
                if arg.startswith('-'):
                    docker_exec_cmd += [arg]
                else:
                    name = arg
            else:
                additional_args += [arg]
        if not name:
            raise TypeError('name must be set.')

        containers = self.containers([('liquid_task', name)])
        container_id = first(containers, f'{name} containers')

        if tty:
            docker_exec_cmd += ['-it']
        docker_exec_cmd += [container_id] + list(additional_args or (['bash'] if tty else []))
        return docker_exec_cmd

    def shell(self, name, *args,stdin=None, tty=False):
        """Run the given command in a docker container tagged with liquid_task=`name`.

        The command output is redirected to the standard output and a tty is opened.
        """
        run_fg(self.exec_command(name, *args, tty=True), stdin=stdin, shell=False)

    def exec_(self, *args, stdin=None):
        run_fg(self.exec_command(*args), stdin=stdin,shell=False)


docker = Docker()
