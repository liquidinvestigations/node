from liquid_node import jobs


class Etherpad(jobs.Job):
    name = 'etherpad'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'etherpad'
