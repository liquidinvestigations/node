from .process import run
from .util import first
from liquid_node.configuration import config
from liquid_node.process import run_fg
from liquid_node.nomad import nomad


class Docker:

    def containers(self, labels=[]):
        label_args = ' '.join(f'-f label={k}={v}' for k, v in labels)
        out = run(f'docker ps -q {label_args}')
        return out.split()

    def exec_command(self, name, *args, tty=False):
        """Prepare and return the command to run in a docker container tagged with
        liquid_task=`name`

        :param name: the value of the liquid_task tag
        :param tty: if true, instruct docker to allocate a pseudo-TTY and keep stdin open
        """

        [job, task] = name.split('-')

        def allocs():
            for alloc in nomad.job_allocations(job):
                if task not in alloc['TaskStates']:
                    continue
                if alloc['ClientStatus'] != 'running':
                    continue
                yield alloc['ID']

        alloc_id = first(list(allocs()), f'{name} allocs')

        docker_exec_cmd = ['docker', 'exec', '-i']

        if tty:
            docker_exec_cmd += ['-t']

        docker_exec_cmd += [
            'cluster',
            '/app/bin/nomad', 'alloc', 'exec',
            '-address', config.nomad_url,
            '-task', task,
            alloc_id,
        ]

        docker_exec_cmd += list(args or (['bash'] if tty else []))
        return docker_exec_cmd

    def shell(self, name, *args):
        """Run the given command in a docker container tagged with liquid_task=`name`.

        The command output is redirected to the standard output and a tty is opened.
        """
        run_fg(self.exec_command(name, *args, tty=True), shell=False)

    def exec_(self, name, *args):
        run_fg(self.exec_command(name, *args), shell=False)


docker = Docker()
