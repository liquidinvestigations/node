from collections import defaultdict
import base64
import pprint
from time import time, sleep
import logging
import urllib.error

from .configuration import config
from .jsonapi import JsonApi
from .util import first, retry
from .docker import docker

log = logging.getLogger(__name__)


def _get_nomad_ui_url_task_logs(alloc_id, task_name):
    return f'{config.nomad_url}/ui/allocations/{alloc_id}/{task_name}/logs'


def scale_cpu_and_memory(spec):
    spec = dict(spec)
    for group in spec.get('TaskGroups', []):
        for task in group['Tasks'] or []:
            task['Resources']['CPU'] = int(task['Resources']['CPU'] * config.container_cpu_scale)
            task['Resources']['MemoryMB'] = int(task['Resources']['MemoryMB']
                                                * config.container_memory_limit_scale)
            if 'memory_hard_limit' in task['Config']:
                task['Config']['memory_hard_limit'] = int(
                    task['Config']['memory_hard_limit'] * config.container_memory_limit_scale
                )
    return spec


def add_labels(spec):
    spec = dict(spec)
    for group in spec.get('TaskGroups', []):
        for task in group['Tasks'] or []:
            if task['Driver'] != 'docker':
                # print(spec['ID'] + '.' + group['Name'] + '.' + task['Name'])
                continue
            else:
                labels = {
                    'nomad_job': spec['ID'],
                    'nomad_group': spec['ID'] + '.' + group['Name'],
                    'nomad_task': spec['ID'] + '.' + group['Name'] + '.' + task['Name'],
                    'liquid_node': 'true',
                }
                if task['Config'].get('labels') and task['Config']['labels'] and task['Config']['labels'][0]:
                    labels.update(task['Config']['labels'][0])
                task['Config']['labels'] = [labels]
                # task['Config']['hostname'] = '${node.unique.name}'
                task['Config']['init'] = True
                task['Config'].setdefault('ulimit', list())
                if not task['Config']['ulimit']:
                    task['Config']['ulimit'].append(dict())
                task['Config']['ulimit'][0].setdefault('nproc', 4096)  # elasticsearch
                task['Config']['ulimit'][0].setdefault('nofile', 262144)  # elasticsearch/clickhouse
                task['Config']['ulimit'][0]['core'] = 0

                # task['Config']['ulimit'][0]['memlock'] = -1
    return spec


def replace_images_with_hashes(spec):
    spec = dict(spec)
    for group in spec.get('TaskGroups', []):
        for task in group['Tasks'] or []:
            if task['Driver'] != 'docker':
                # print(spec['ID'] + '.' + group['Name'] + '.' + task['Name'])
                continue
            else:
                config = task['Config']
                try:
                    new_image = docker.pull(config['image'], force=False)
                    config['image'] = new_image
                except Exception as e:
                    log.warning(
                        'cannot get image hash for %s: %s',
                        config['image'],
                        str(e),
                    )
    return spec


class Nomad(JsonApi):

    def __init__(self, endpoint):
        super().__init__(endpoint + '/v1/')

    def parse(self, hcl, replace_images=False):
        try:
            result = add_labels(scale_cpu_and_memory(
                self.post('jobs/parse', {'JobHCL': hcl, 'Canonicalize': True})))
            if replace_images:
                result = replace_images_with_hashes(result)
            return result

        except urllib.error.HTTPError as e:
            hcl_with_lineno = "\n".join(f"{i+1: 4d} {line}" for i, line in enumerate(hcl.splitlines()))
            log.debug('hcl: \n%s', hcl_with_lineno)
            log.error(e.read().decode('utf-8'))
            raise e

    def run(self, spec, check_batch_jobs=False):
        t0 = int(time())
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
            log.debug('spec: %s', pprint.pformat(spec))
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

        if check_batch_jobs:
            if spec.get('Type') == 'batch':
                self.wait_for_batch_job(spec, evaluation, t0)

    def wait_for_batch_job(self, spec, evaluation, t0):
        PRINT_EVERY_S = 120
        next_print = time() + PRINT_EVERY_S
        INTERVAL_S = 2
        TOTAL_WAIT_H = 3

        def check_eval(evaluation):
            ev = self.get('evaluations?prefix=' + evaluation['EvalID'])
            return ev[0]['Status'] == 'complete'

        def check_job(spec):
            job = self.get(f'job/{spec["ID"]}')
            return job['Status'] == 'dead'

        log.info("Waiting for batch job %s  (max wait = %sh)", spec['ID'], TOTAL_WAIT_H)
        printed_something = False
        for _ in range(int(TOTAL_WAIT_H * 3600 / INTERVAL_S)):
            if check_eval(evaluation) and check_job(spec):
                # TODO: check allocations for each taskgroup to see if we have one that succeeded.
                # Otherwise, this passes on for failed, non-repeating tasks.
                break

            if time() > next_print:
                PRINT_EVERY_S *= 2
                next_print = time() + PRINT_EVERY_S
                log.warning(
                    "job '%s' still running after %s min; will wait for another %s min",
                    spec['ID'], int((time() - t0) / 60), TOTAL_WAIT_H * 60 - int((time() - t0) / 60),
                )
            if not printed_something:
                printed_something |= self.check_events_and_logs(spec['ID'], t0)

            sleep(INTERVAL_S)
        else:
            raise RuntimeError("Batch Job {spec['ID']} Failed to finish in 2h")

        log.info('Batch job %s completed successfully.', spec['ID'])

    def get_health_checks_from_spec(self, spec):
        """Generates (service, check_name_list) tuples for the supplied job spec"""

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
        """Generates (task, count, type, resources) tuples with resource info for
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
        # return jobs in reverse chronological order (newest first)
        return self.get(f'job/{job}/allocations?reverse=true')

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

    def stop_and_wait(self, jobs, nowait=False):
        from liquid_node.configuration import config

        if not jobs:
            return

        log.debug('Stopping jobs: ' + ', '.join(jobs))
        for job in jobs:
            self.stop(job)

        if nowait:
            return
        jobs = list(jobs)
        log.debug('Waiting for the following jobs to die: ' + ', '.join(jobs))
        timeout = time() + config.wait_max

        while jobs and time() < timeout:
            just_removed = []

            nomad_jobs = {job['ID']: job for job in self.jobs() if job['ID'] in jobs}
            for job_name in jobs:
                if job_name not in nomad_jobs or nomad_jobs[job_name]['Status'] == 'dead':
                    jobs.remove(job_name)
                    just_removed.append(job_name)

            if just_removed:
                log.info('Jobs stopped: ' + ", ".join(just_removed))

            if not jobs:
                break

            sleep(config.wait_interval / 3)

        if jobs:
            raise RuntimeError(f'The following jobs are still running: {jobs}')

    def gc(self):
        return self.put('system/gc', None)

    def get_address(self):
        """Return the nomad server's address."""

        members = [m['Addr'] for m in self.agent_members()]
        return first(members, 'members')

    def check_events_and_logs(self, job_name, deployment_time=None):
        """Prints the last logs for restarting or hanging task.

        Returns True if we found bad allocs and printed out the logs for them;
        this means we shouldn't run this function again on this job.

        If the job is missing, print a DEBUG message and skip it.
        This happens for batch tasks that have finished and are removed.
        """

        # check if the job still exists; if not, skip it...
        try:
            job = self.get(f'job/{job_name}')
            assert job['ID'] == job_name, 'unknown job id'
        except urllib.error.HTTPError as e:
            # status 404 is expected when the batch job is long dead.
            if e.status != 404:
                log.warning('job cannot be fetched: %s (%s)', job_name, e)
            return False

        try:
            return self.check_recent_restarts(job_name, deployment_time) \
                or self.check_long_running_batch(job_name)
        except Exception as e:
            log.exception(e)
            return False

    def check_long_running_batch(self, job_name):
        """Print out logs for very long-running batch jobs.

        Returns True if found something.
        """
        MAX_RUNNING_AGE = 300

        job_config = self.get(f'job/{job_name}')
        if job_config['Type'] != 'batch':
            return False

        allocations = self.get(f'job/{job_name}/allocations')
        if not allocations:
            return False

        printed_something = False
        for alloc in allocations:
            if alloc['ClientStatus'] != 'running':
                continue
            alloc_age = int(time() - alloc["ModifyTime"] / 1000000000.0)
            if alloc_age > MAX_RUNNING_AGE:
                for task_name, task_state_obj in (alloc['TaskStates'] or {}).items():
                    if task_state_obj['State'] == 'running':
                        log.warning(
                            'Batch Job "%s:%s" has been running for %s sec.',
                            job_name, task_name, alloc_age,
                        )
                        printed_something |= self.print_logs(job_name, alloc['ID'], task_name)
        if printed_something:
            log.warning('The batch job "%s" is taking a long time to finish.', job_name)
            log.warning('This is normal for large data migrations; see logs above for details.')
        return printed_something

    def check_recent_restarts(self, job_name, deployment_time=None):
        """Prints the last logs for restarting task. Returns True if printed something.

        This should pick up excessive restarts, even for running tasks.
        It should aggregate restarts since the deployment, or 10 minutes
        if not deploying, and trigger on 8 or more events.
        """
        if not deployment_time:
            MIN_EVENT_TIME = int(time() - 600)
        else:
            MIN_EVENT_TIME = int(deployment_time)

        # Get number of retries and failures
        task_retry_count = defaultdict(int)
        task_fail_count = defaultdict(int)
        allocs_with_recent_events = defaultdict(set)
        event_msgs = defaultdict(list)

        allocations = self.get(f'job/{job_name}/allocations')
        if not allocations:
            return False

        for allocation in allocations:
            alloc_id = allocation['ID']
            for task_name, task_state_obj in (allocation['TaskStates'] or {}).items():
                for event in task_state_obj['Events']:
                    event_type = event['Type']
                    event_msg = event.get('DisplayMessage')
                    event_time = event['Time'] / 1000000000.0
                    if event_time < MIN_EVENT_TIME:
                        continue
                    # now register this event
                    allocs_with_recent_events[task_name].add(alloc_id)
                    event_age = int(time() - event_time)
                    event_msgs[task_name].append(f'[{event_age}s ago] {event_msg}')
                    event_fails_task = event['FailsTask']

                    if event_type == 'Restarting':
                        task_retry_count[task_name] += 1
                    if event_fails_task:
                        task_fail_count[task_name] += 1

        def _alloc_mtime(the_alloc_id):
            for a in allocations:
                if a['ID'] == the_alloc_id:
                    return a['ModifyTime']

        printed_something = False
        tasks = sorted(set(task_retry_count.keys()) | set(task_fail_count.keys()))
        for task_name in tasks:
            if task_retry_count[task_name] >= 4 or task_fail_count[task_name] >= 1:
                event_text = "\n".join(event_msgs[task_name])
                log.warning(
                    'Task "%s:%s" has restarts=%s fails=%s in the past %s sec:\n%s',
                    job_name, task_name, task_retry_count[task_name],
                    task_fail_count[task_name], int(time() - MIN_EVENT_TIME),
                    event_text,
                )

                alloc_ids = allocs_with_recent_events[task_name]
                alloc_ids = sorted(alloc_ids, key=lambda x: -_alloc_mtime(x))
                printed_something |= self._print_all_logs(job_name, task_name, alloc_ids)
        if printed_something:
            log.warning("Job %s has a task in a restart loop! Logs above.", job_name)
        return printed_something

    def _print_all_logs(self, job_name, task_name, alloc_id_list):
        """Checks all allocations if we have any logs - and prints first found if we do."""

        log.debug('finding logs for "%s:%s"!', job_name, task_name)
        found = any(self.print_logs(job_name, a, task_name) for a in alloc_id_list)
        if not found:
            log.warning('Could not find any logs for "%s:%s"!', job_name, task_name)
        return found

    def print_logs(self, job_name, alloc_id, task_name, offset=2000):
        """Prints the logs for some allocation to the standard operator.

        Returns true if it succeeded in fetching logs."""

        def get_type(log_type):
            def _get_content():
                url = f'client/fs/logs/{alloc_id}?follow=false&offset={offset}&origin=end&task={task_name}&type={log_type}'  # noqa: #501
                content = self.get(url)
                if not content:
                    return ''
                content = content.get('Data')
                if not content:
                    return ''
                content = base64.b64decode(content)
                if not content:
                    return ''
                content = content.decode('ascii', errors='replace')
                content = '\n|    '.join(line for line in content.splitlines()[-40:])
                return content

            try:
                content = _get_content()
                if not content:
                    raise RuntimeError(f'No logs ({log_type}) for task "{job_name}:{task_name}')
                content = f'\n|---------- [{log_type} for task "{job_name}:{task_name}"] ----------\n|\n|    {content}\n|\n|----------------------\n'  # noqa: E501
                return content
            except Exception as e:
                log.debug(e)
                return ''

        content = get_type('stdout') + get_type('stderr')
        if content:
            log.warning('Log Outputs for "%s:%s":\n%s', job_name, task_name, content)
            log.warning('See more logs for "%s:%s" on Nomad UI:', job_name, task_name)
            log.warning('  %s', _get_nomad_ui_url_task_logs(alloc_id, task_name))
            return True
        log.debug('No log outputs found for task "%s:%s"', job_name, task_name)
        return False

    def wait_for_service_health_checks(self, consul, job_names, health_checks, deploy_t0=None, nowait=False):
        """Waits health checks to become green for green_count times in a row.

        If nowait is set to True, then instantly returns True if something fails, or False for no errors."""

        if not health_checks:
            return

        if not deploy_t0:
            deploy_t0 = time()

        def pick_worst(a, b):
            if not a and not b:
                return 'missing'
            for s in ['critical', 'warning', 'passing']:
                if s in [a, b]:
                    return s
            raise RuntimeError(f'Unknown status: "{a}" and "{b}"')

        def get_checks():
            """Generates a list of (service, check, status)
            for all failing checks after checking with Consul"""

            consul_status = {}
            healthy_nodes = [n['Name'] for n in self.get('nodes')
                             if n['Status'] == 'ready'
                             and n['SchedulingEligibility'] == 'eligible']
            for service in health_checks:
                for s in consul.get(f'/health/checks/{service}'):
                    if s['Node'] not in healthy_nodes:
                        continue
                    key = service, s['Name']
                    consul_status[key] = pick_worst(s['Status'], consul_status.get(key))

            for service, checks in health_checks.items():
                for check in checks:
                    status = consul_status.get((service, check), 'missing')
                    yield service, check, status

        t0 = time()
        last_check_timestamps = {}
        passing_count = defaultdict(int)

        def log_checks(checks, as_error=False, print_passing=True):
            max_service_len = max(len(s) for s in health_checks.keys())
            max_name_len = max(max(len(name) for name in health_checks[key]) for key in health_checks)
            now = time()
            for service, check, status in checks:
                last_time = last_check_timestamps.get((service, check), t0)
                after = f'{now - last_time:+.1f}s'
                last_check_timestamps[service, check] = now

                line = f'[{time() - t0:4.1f}] {service:>{max_service_len}}: {check:<{max_name_len}} {status.upper():<8} {after:>5}'  # noqa: E501

                if status == 'passing':
                    if as_error:
                        continue
                    if not print_passing:
                        continue
                    passing_count[service, check] += 1
                    if passing_count[service, check] > 1:
                        line += f' #{passing_count[service, check]}'
                    log.info(line)
                elif as_error:
                    log.error(line)
                else:
                    log.warning(line)

        services = sorted(health_checks.keys())
        if not nowait:
            log.info(f"Waiting for health checks on {len(services)} services")

        greens = 0
        timeout = t0 + config.wait_max + config.wait_interval * config.wait_green_count
        last_checks = set(get_checks())
        log_checks(last_checks, print_passing=False)
        printed_alloc_errors_for_job = []
        while time() < timeout:

            checks = set(get_checks())
            log_checks(checks - last_checks)
            last_checks = checks

            if any(status != 'passing' for _, _, status in checks):
                greens = 0
                # print the allocation jobs, but only if we didn't already do that
                for job in job_names:
                    if job in printed_alloc_errors_for_job:
                        continue
                    if self.check_events_and_logs(job, deploy_t0):
                        printed_alloc_errors_for_job.append(job)
            else:
                greens += 1

            if greens >= config.wait_green_count or nowait:
                if nowait:
                    if greens:
                        log.info(f"Checks green for {len(services)} services.")
                        return False
                    else:
                        log.error('Some service checks are not healthy.')
                        return True
                else:
                    log.info(f"Checks green for {len(services)} services after {time() - t0:.02f}s")
                return False

            # No chance to get enough greens
            no_chance_timestamp = timeout - config.wait_interval * config.wait_green_count
            if greens == 0 and time() >= no_chance_timestamp:
                break
            if nowait:
                log.error('Some service checks are not healthy.')
                return True
            sleep(config.wait_interval)

        log_checks(checks, as_error=True)
        msg = f'Checks are failed after {time() - t0:.02f}s.'
        raise RuntimeError(msg)


nomad = Nomad(config.nomad_url)
