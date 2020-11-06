from liquid_node import jobs


class Hoover(jobs.Job):
    name = 'hoover'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hoover'
    stage = 2


class Workers(jobs.Job):
    name = 'hoover-workers'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hoover-workers'
    stage = 3


class Proxy(jobs.Job):
    name = 'hoover-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hoover'
    stage = 4


class Deps(jobs.Job):
    name = 'hoover-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    pg_tasks = ['search-pg', 'snoop-pg']
    app = 'hoover'
    stage = 1


class Nginx(jobs.Job):
    name = 'hoover-nginx'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hoover'
    stage = 3
