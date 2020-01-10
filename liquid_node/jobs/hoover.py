from liquid_node import jobs


class Hoover(jobs.Job):
    name = 'hoover'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hoover'


class Ui(jobs.Job):
    name = 'hoover-ui'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hoover'


class Deps(jobs.Job):
    name = 'hoover-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    pg_task = 'hoover-pg'
    app = 'hoover'


class System(jobs.Job):
    name = 'hoover-system'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hoover'
