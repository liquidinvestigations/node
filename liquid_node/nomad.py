from .configuration import config
from .jsonapi import JsonApi
from .util import first


class Nomad(JsonApi):

    def __init__(self, endpoint):
        super().__init__(endpoint + '/v1/')

    def parse(self, hcl):
        return self.post(f'jobs/parse', {'JobHCL': hcl, 'Canonicalize': True})

    def run(self, spec):
        self.post(f'jobs', {'job': spec})

        job_id = spec['ID']
        if spec.get('Periodic'):
            # HTTP 500 - "can't evaluate periodic job"
            return
        self.post(f'job/{job_id}/evaluate',
                  {'JobID': job_id,
                   "EvalOptions": {"ForceReschedule": True}})

    def get_health_checks(self, spec):
        """Generates (service, check_name_list) tuples for the supplied job"""

        def name(check):
            assert check['Name'], (
                f'Service check for service "{service["Name"]}" should have a name'
            )
            return check['Name']

        for group in spec['TaskGroups'] or []:
            for task in group['Tasks'] or []:
                for service in task['Services'] or []:
                    yield service['Name'], [name(check) for check in service['Checks'] or []]

    def get_resources(self, spec):
        """Generates (task, type, resources) tuples with resource stranzas for
        the supplied job."""

        for group in spec['TaskGroups'] or []:
            group_name = f'{spec["Name"]}-{group["Name"]}'
            yield group_name, spec['Type'], {'EphemeralDiskMB': group['EphemeralDisk']['SizeMB']}
            for task in group['Tasks'] or []:
                name = f'{group_name}-{task["Name"]}'
                yield name, spec['Type'], task['Resources']

    def jobs(self):
        return self.get(f'jobs')

    def job_allocations(self, job):
        return self.get(f'job/{job}/allocations')

    def agent_members(self):
        return self.get('agent/members')['Members']

    def stop(self, job):
        return self.delete(f'job/{job}')

    def gc(self):
        return self.put('system/gc', None)

    def get_address(self):
        """Return the nomad server's address."""

        members = [m['Addr'] for m in self.agent_members()]
        return first(members, 'members')


nomad = Nomad(config.nomad_url)
