from liquid_node import jobs


class Codimd(jobs.Job):
    name = 'codimd'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'codimd'
