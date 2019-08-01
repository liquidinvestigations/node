from liquid_node import jobs


class Rocketchat(jobs.Job):
    name = 'rocketchat'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'rocketchat'


class Migrate(jobs.Job):
    name = 'rocketchat-migrate'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'rocketchat'
