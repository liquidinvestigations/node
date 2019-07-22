from liquid_node import jobs


class Hoover(jobs.Job):
    name = 'hoover'
    template = jobs.TEMPLATES / f'{name}.nomad'
    pg_task = name + '-pg'


class Ui(jobs.Job):
    name = 'hoover-ui'
    template = jobs.TEMPLATES / f'{name}.nomad'
