from liquid_node import jobs


class Dokuwiki(jobs.Job):
    name = 'dokuwiki'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'dokuwiki'
    stage = 2


class Proxy(jobs.Job):
    name = 'dokuwiki-proxy'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'dokuwiki'
    stage = 4
