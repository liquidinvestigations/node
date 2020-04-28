from liquid_node import jobs


class Nextcloud(jobs.Job):
    name = 'nextcloud'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'


class Migrate(jobs.Job):
    name = 'nextcloud-migrate'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'


class Periodic(jobs.Job):
    name = 'nextcloud-periodic'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'


class Database(jobs.Job):
    name = 'nextcloud-database'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'
