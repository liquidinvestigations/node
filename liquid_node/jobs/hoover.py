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
    pg_tasks = ['search-pg', 'snoop-pg']
    app = 'hoover'
