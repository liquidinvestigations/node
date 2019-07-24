from liquid_node import jobs


class Rocketchat(jobs.Job):
    name = 'rocketchat'
    template = jobs.TEMPLATES / f'{name}.nomad'


class Migrate(jobs.Job):
    name = 'rocketchat-migrate'
    template = jobs.TEMPLATES / f'{name}.nomad'


jobs = (Rocketchat(), Migrate(), )
