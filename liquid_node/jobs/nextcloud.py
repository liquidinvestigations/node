from liquid_node import jobs


class Nextcloud(jobs.Job):
    name = 'nextcloud'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'
    stage = 2


class Migrate(jobs.Job):
    name = 'nextcloud-migrate'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'
    stage = 3


class Periodic(jobs.Job):
    name = 'nextcloud-periodic'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'
    stage = 3


class Proxy(jobs.Job):
    name = 'nextcloud-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'
    stage = 4


class Deps(jobs.Job):
    name = 'nextcloud-deps'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'nextcloud'
    stage = 1
