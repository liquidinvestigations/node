from liquid_node import jobs


class Nextcloud(jobs.Job):
    name = 'nextcloud'
    template = jobs.TEMPLATES / f'{name}.nomad'


class Migrate(jobs.Job):
    name = 'nextcloud-migrate'
    template = jobs.TEMPLATES / f'{name}.nomad'
