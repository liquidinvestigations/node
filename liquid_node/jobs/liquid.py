from liquid_node import jobs


class Liquid(jobs.Job):
    name = 'liquid'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'liquid'


class Ingress(jobs.Job):
    name = 'ingress'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'liquid'
