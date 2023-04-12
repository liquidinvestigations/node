from liquid_node import jobs


class Liquid(jobs.Job):
    name = 'liquid'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'liquid'
    stage = 0
    vault_secret_keys = [
        'liquid/liquid/core.django',
    ]


class Ingress(jobs.Job):
    name = 'ingress'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'liquid'
    stage = 1


class CreateUser(jobs.Job):
    name = 'liquid-createuser'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'liquid'
    stage = 3


class DeleteUser(jobs.Job):
    name = 'liquid-deleteuser'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'liquid'
    stage = 3


class CreateGroup(jobs.Job):
    name = 'liquid-creategroup'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'liquid'
    stage = 3


class AuthproxyRedis(jobs.Job):
    name = 'authproxy-redis'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'liquid'
    stage = 0


class SystemDeps(jobs.Job):
    name = 'system-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'liquid'
    stage = 0


class Monitoring(jobs.Job):
    name = 'monitoring'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'liquid'
    stage = 0
