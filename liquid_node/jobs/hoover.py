from liquid_node import jobs


class Hoover(jobs.Job):
    name = 'hoover'
    template = jobs.TEMPLATES / f'{name}.nomad'


class Ui(jobs.Job):
    name = 'hoover-ui'
    template = jobs.TEMPLATES / f'{name}.nomad'


class Deps(jobs.Job):
    name = 'hoover-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    pg_task = 'hoover-pg'
