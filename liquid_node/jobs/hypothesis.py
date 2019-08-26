from liquid_node import jobs


class Hypothesis(jobs.Job):
    name = 'hypothesis'
    template = jobs.TEMPLATES / f'{name}.nomad'
    app = 'hypothesis'
