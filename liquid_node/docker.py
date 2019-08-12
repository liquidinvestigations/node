from .process import run
from .util import first
from liquid_node.process import run_fg


class Docker:

    def containers(self, labels=[]):
        label_args = ' '.join(f'-f label={k}={v}' for k, v in labels)
        out = run(f'docker ps -q {label_args}')
        return out.split()

    def exec_command(self, *args):
        """Prepare and return the command to run in a docker container tagged with
        liquid_task=`name`.
        you can give the same flags to the command as to docker exec, at the beginning
        of your command. The first argument, which doesn't start with '-' is interpreted
        as the container name.

        :param name: the value of the liquid_task tag
        """
        taken_args = []
        docker_exec_cmd = ['docker', 'exec']
        for arg in args:
            if arg.startswith('-'):
                docker_exec_cmd += [arg]
                taken_args += [arg]
            else:
                name = arg
                taken_args += [arg]
                break
        
        containers = self.containers([('liquid_task', name)])
        container_id = first(containers, f'{name} containers')
        docker_exec_cmd += [container_id] + list(args or (['bash'] if tty else []))

        return docker_exec_cmd

    def shell(self, name, *args):
        """Run the given command in a docker container tagged with liquid_task=`name`.

        The command output is redirected to the standard output and a tty is opened.
        """
        run_fg(self.exec_command(name, *args, tty=True), shell=False)

    def exec_(self, name, *args):
        run_fg(self.exec_command(name, *args), shell=False)


docker = Docker()
