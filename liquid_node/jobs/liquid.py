from liquid_node import jobs


class Liquid(jobs.Job):
    name = 'liquid'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'liquid'
