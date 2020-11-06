from liquid_node import jobs


class Rocketchat(jobs.Job):
    name = 'rocketchat'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'rocketchat'
    stage = 3


class Deps(jobs.Job):
    name = 'rocketchat-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'rocketchat'
    stage = 1


class Migrate(jobs.Job):
    name = 'rocketchat-migrate'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'rocketchat'
    stage = 2


class Proxy(jobs.Job):
    name = 'rocketchat-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'rocketchat'
    stage = 4
