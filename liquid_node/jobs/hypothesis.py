from liquid_node import jobs


class Hypothesis(jobs.Job):
    name = 'hypothesis'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hypothesis'
    stage = 2


class Deps(jobs.Job):
    name = 'hypothesis-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hypothesis'
    stage = 1


class UserSync(jobs.Job):
    name = 'hypothesis-usersync'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hypothesis'
    stage = 3


class Proxy(jobs.Job):
    name = 'hypothesis-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hypothesis'
    stage = 4
