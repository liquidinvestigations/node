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
            log.debug('hcl: %s', hcl)
            raise e

    def run(self, spec):
        if spec.get('Type') != 'batch':
            if not spec.get('Update'):
                spec['Update'] = {}
            spec['Update']['MaxParallel'] = 0
            for group in spec.get('TaskGroups', []):
                if not group.get('Update'):
                    group['Update'] = {}
                group['Update']['MaxParallel'] = 0
        try:
            self.post('jobs', {'job': spec})
        except urllib.error.HTTPError as e:
            log.error(e.read().decode('utf-8'))
            raise e

        job_id = spec['ID']
        if spec.get('Periodic') or spec.get('ParameterizedJob'):
            # HTTP 500 - "can't evaluate periodic/parameterized job"
            return

        evaluation = self.post(
            f'job/{job_id}/evaluate',
            {'JobID': job_id, "EvalOptions": {"ForceReschedule": True}},
        )

        if spec.get('Type') == 'batch':
            self.wait_for_batch_job(spec, evaluation)

    def wait_for_batch_job(self, spec, evaluation):
        INTERVAL_S = 2
        TOTAL_WAIT_H = 2

        def check_eval(evaluation):
            ev = self.get('evaluations?prefix=' + evaluation['EvalID'])
            return ev[0]['Status'] == 'complete'

        def check_job(spec):
            job = self.get(f'job/{spec["ID"]}')
            log.debug("job %s status is '%s'", spec['ID'], job['Status'])
            return job['Status'] == 'dead'

        log.info("Waiting for batch job %s  (max wait = %sh)", spec['ID'], TOTAL_WAIT_H)
        for _ in range(int(TOTAL_WAIT_H * 3600 / INTERVAL_S)):
            sleep(INTERVAL_S)
            if check_eval(evaluation) and check_job(spec):
                break
        else:
            raise RuntimeError("Batch Job {spec['ID']} Failed to finish in 2h")

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

    def get_available_resources(self):
        cpu_shares = 0
        cpu_count = 0
        memory_mb = 0
        disk_mb = 0
        node_count = 0

        for node in self.get('nodes'):
            if node['Status'] != "ready" or node['SchedulingEligibility'] != "eligible":
                continue
            node_info = self.get('node/' + node['ID'])

            cpu_shares += int(node_info['Resources']['CPU'])
            memory_mb += int(node_info['Resources']['MemoryMB'])
            disk_mb += int(node_info['Resources']['DiskMB'])
            cpu_count += int(node_info['Attributes']['cpu.numcores'])
            node_count += 1
        return {
            "CPU": cpu_shares,
            "MemoryMB": memory_mb,
            "EphemeralDiskMB": disk_mb,
            "cpu_count": cpu_count,
            "node_count": node_count,
        }

    def get_images(self, spec):
        """Generates docker image names from spec."""

        for group in spec['TaskGroups'] or []:
            for task in group['Tasks'] or []:
                if task['Driver'] == 'docker':
                    yield task['Config']['image']

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
