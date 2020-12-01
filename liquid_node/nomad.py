from time import time, sleep
import logging
import urllib.error

from .configuration import config
from .jsonapi import JsonApi
from .util import first, retry


log = logging.getLogger(__name__)


class Nomad(JsonApi):

    def __init__(self, endpoint):
        super().__init__(endpoint + '/v1/')

    def parse(self, hcl):
        try:
            return self.post('jobs/parse', {'JobHCL': hcl, 'Canonicalize': True})
        except urllib.error.HTTPError as e:
            log.error(e.read().decode('utf-8'))
            raise e

    def run(self, spec):
        try:
            self.post('jobs', {'job': spec})
        except urllib.error.HTTPError as e:
            log.error(e.read().decode('utf-8'))
            raise e

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
        """Generates (task, count, type, resources) tuples with resource stranzas for
        the supplied job."""

        for group in spec['TaskGroups'] or []:
            group_name = f'{spec["Name"]}-{group["Name"]}'
            count = group['Count']
            yield group_name, count, spec['Type'], {'EphemeralDiskMB': group['EphemeralDisk']['SizeMB']}
            for task in group['Tasks'] or []:
                name = f'{group_name}-{task["Name"]}'
                yield name, count, spec['Type'], task['Resources']

    def jobs(self):
        return self.get('jobs')

    def job_allocations(self, job):
        return self.get(f'job/{job}/allocations')

    @retry()
    def restart(self, job, task):
        def allocs():
            for alloc in self.job_allocations(job):
                if task not in alloc['TaskStates']:
                    continue
                if alloc['ClientStatus'] != 'running':
                    continue
                yield alloc['ID']

        hit = False
        for alloc_id in allocs():
            log.info(f'Restarting allocation for job "{job}", task "{task}", id {alloc_id}')
            self.post(f'allocation/{alloc_id}/stop')
            hit = True
        if not hit:
            raise RuntimeError(f'no allocs to restart job="{job}" task="{task}"')

    def agent_members(self):
        return self.get('agent/members')['Members']

    def stop(self, job):
        return self.delete(f'job/{job}')

    def stop_and_wait(self, jobs):
        from liquid_node.configuration import config

        if not jobs:
            return

        log.debug('Stopping jobs: ' + ', '.join(jobs))
        for job in jobs:
            self.stop(job)

        jobs = list(jobs)
        log.debug('Waiting for the following jobs to die: ' + ', '.join(jobs))
        timeout = time() + config.wait_max

        while jobs and time() < timeout:
            sleep(config.wait_interval / 3)
            just_removed = []

            nomad_jobs = {job['ID']: job for job in self.jobs() if job['ID'] in jobs}
            for job_name in jobs:
                if job_name not in nomad_jobs or nomad_jobs[job_name]['Status'] == 'dead':
                    jobs.remove(job_name)
                    just_removed.append(job_name)

            if just_removed:
                log.info('Jobs stopped: ' + ", ".join(just_removed))

        if jobs:
            raise RuntimeError(f'The following jobs are still running: {jobs}')

    def gc(self):
        return self.put('system/gc', None)

    def get_address(self):
        """Return the nomad server's address."""

        members = [m['Addr'] for m in self.agent_members()]
        return first(members, 'members')


nomad = Nomad(config.nomad_url)
