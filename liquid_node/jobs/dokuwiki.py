from liquid_node import jobs


class Dokuwiki(jobs.Job):
    name = 'dokuwiki'
    template = jobs.TEMPLATES / f'{name}.nomad'


class Migrate(jobs.Job):
    name = 'dokuwiki-migrate'
    template = jobs.TEMPLATES / f'{name}.nomad'
