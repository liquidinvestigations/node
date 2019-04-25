from .process import run
from .util import first


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
        containers = self.containers([('liquid_task', name)])
        container_id = first(containers, 'containers')
    
        docker_exec_cmd = ['docker', 'exec']
        if tty:
            docker_exec_cmd += ['-it']
        docker_exec_cmd += [container_id] + list(args or (['bash'] if tty else []))
    
        return docker_exec_cmd


docker = Docker()
