from liquid_node import jobs


class Hoover(jobs.Job):
    name = 'hoover'
    template = jobs.TEMPLATES / f'{name}.nomad'


class Ui(jobs.Job):
    name = 'hoover-ui'
    template = jobs.TEMPLATES / f'{name}.nomad'


class Migrate(jobs.Job):
    name = 'hoover-migrate'
    template = jobs.TEMPLATES / f'{name}.nomad'
