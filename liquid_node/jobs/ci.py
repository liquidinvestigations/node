from liquid_node import jobs


class Drone(jobs.Job):
    name = 'drone'
    template = jobs.TEMPLATES / f'{name}.nomad'
