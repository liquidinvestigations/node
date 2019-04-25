from .configuration import config
from .jsonapi import JsonApi
from .util import first


class Nomad(JsonApi):

    def __init__(self, endpoint):
        super().__init__(endpoint + '/v1/')

    def run(self, hcl):
        spec = self.post(f'jobs/parse', {'JobHCL': hcl})
        return self.post(f'jobs', {'job': spec})

    def get_health_checks(self, hcl):
        """Generates (service, check_name_list) tuples for the supplied job"""

        def name(check):
            assert check['Name'], (
                f'Service check for service "{service["Name"]}" should have a name'
            )
            return check['Name']

        spec = self.post(f'jobs/parse', {'JobHCL': hcl})
        for group in spec['TaskGroups'] or []:
            for task in group['Tasks'] or []:
                for service in task['Services'] or []:
                    yield service['Name'], [name(check) for check in service['Checks'] or []]

    def jobs(self):
        return self.get(f'jobs')

    def job_allocations(self, job):
        return self.get(f'job/{job}/allocations')

    def agent_members(self):
        return self.get('agent/members')['Members']

    def stop(self, job):
        return self.delete(f'job/{job}')

    def get_address(self):
        """Return the nomad server's address."""

        members = [m['Addr'] for m in self.agent_members()]
        return first(members, 'members')


nomad = Nomad(config.nomad_url)
