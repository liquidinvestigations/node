from liquid_node import jobs


class Codimd(jobs.Job):
    name = 'codimd'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'codimd'
    stage = 2


class Deps(jobs.Job):
    name = 'codimd-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'codimd'
    stage = 1


class Proxy(jobs.Job):
    name = 'codimd-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'codimd'
    stage = 4
