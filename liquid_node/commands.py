from pathlib import Path
from collections import defaultdict
from time import time, sleep
import logging
import os
import base64
import json
import argparse

from liquid_node.jobs import wait_for_stopped_jobs
from .configuration import config
from .consul import consul
from .jobs import get_job, hoover
from .nomad import nomad
from .process import run
from .util import first
from .docker import docker
from .vault import vault


log = logging.getLogger(__name__)

CORE_AUTH_APPS = [
    {
        'name': 'authdemo',
        'vault_path': 'liquid/authdemo/auth.oauth2',
        'callback': f'{config.app_url("authdemo")}/__auth/callback',
    },
    {
        'name': 'hoover',
        'vault_path': 'liquid/hoover/auth.oauth2',
        'callback': f'{config.app_url("hoover")}/__auth/callback',
    },
    {
        'name': 'dokuwiki',
        'vault_path': 'liquid/dokuwiki/auth.oauth2',
        'callback': f'{config.app_url("dokuwiki")}/__auth/callback',
    },
    {
        'name': 'rocketchat-authproxy',
        'vault_path': 'liquid/rocketchat/auth.oauth2',
        'callback': f'{config.app_url("rocketchat")}/__auth/callback',
    },
    {
        'name': 'rocketchat-app',
        'vault_path': 'liquid/rocketchat/app.oauth2',
        'callback': f'{config.app_url("rocketchat")}/_oauth/liquid',
    },
    {
        'name': 'nextcloud',
        'vault_path': 'liquid/nextcloud/auth.oauth2',
        'callback': f'{config.app_url("nextcloud")}/__auth/callback',
    },
    {
        'name': 'codimd-app',
        'vault_path': 'liquid/codimd/app.auth.oauth2',
        'callback': f'{config.app_url("codimd")}/auth/oauth2/callback',
    },
    {
        'name': 'codimd-authproxy',
        'vault_path': 'liquid/codimd/auth.oauth2',
        'callback': f'{config.app_url("codimd")}/__auth/callback',
    },
    {
        'name': 'hypothesis',
        'vault_path': 'liquid/hypothesis/auth.oauth2',
        'callback': f'{config.app_url("hypothesis")}/__auth/callback',
    },
]


def random_secret(bits=256):
    """ Generate a crypto-quality 256-bit random string. """
    return str(base64.b16encode(os.urandom(int(bits / 8))), 'latin1').lower()


def ensure_secret(path, get_value):
    if not vault.read(path):
        log.info(f"Generating value for {path}")
        vault.set(path, get_value())


def ensure_secret_key(path):
    ensure_secret(path, lambda: {'secret_key': random_secret()})


def wait_for_service_health_checks(health_checks):
    """Waits health checks to become green for green_count times in a row. """

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
        for service in health_checks:
            for s in consul.get(f'/health/checks/{service}'):
                key = service, s['Name']
                consul_status[key] = pick_worst(s['Status'], consul_status.get(key))

        for service, checks in health_checks.items():
            for check in checks:
                status = consul_status.get((service, check), 'missing')
                yield service, check, status

    t0 = time()
    last_check_timestamps = {}
    passing_count = defaultdict(int)

    def log_checks(checks, as_error=False):
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
                passing_count[service, check] += 1
                if passing_count[service, check] > 1:
                    line += f' #{passing_count[service, check]}'
                log.info(line)
            elif as_error:
                log.error(line)
            else:
                log.warning(line)

    services = sorted(health_checks.keys())
    log.info(f"Waiting for health checks on {services}")

    greens = 0
    timeout = t0 + config.wait_max + config.wait_interval * config.wait_green_count
    last_checks = set(get_checks())
    log_checks(last_checks)
    while time() < timeout:
        sleep(config.wait_interval)

        checks = set(get_checks())
        log_checks(checks - last_checks)
        last_checks = checks

        if any(status != 'passing' for _, _, status in checks):
            greens = 0
        else:
            greens += 1

        if greens >= config.wait_green_count:
            log.info(f"Checks green {services} after {time() - t0:.02f}s")
            return

        # No chance to get enough greens
        no_chance_timestamp = timeout - config.wait_interval * config.wait_green_count
        if greens == 0 and time() >= no_chance_timestamp:
            break

    log_checks(checks, as_error=True)
    msg = f'Checks are failed after {time() - t0:.02f}s.'
    raise RuntimeError(msg)


def resources():
    """Get memory and CPU usage for the deployment"""

    def get_all_res():
        jobs = [nomad.parse(get_job(job.template)) for job in config.enabled_jobs]
        for spec in jobs:
            yield from nomad.get_resources(spec)

    total = defaultdict(int)
    for name, _type, res in get_all_res():
        for key in ['MemoryMB', 'CPU', 'EphemeralDiskMB']:
            if key not in res:
                continue
            if res[key] is None:
                raise RuntimeError("Please update Nomad to 0.9.3+")
            total[f'{_type} {key}'] += res[key]

    print('Resource requirement totals: ')
    for key, value in sorted(total.items()):
        print(f'  {key}: {value}')


def check_system_config():
    """Raises errors if the system is improperly configured.

    This checks if elasticsearch will accept our
    vm.max_map_count kernel parameter value.
    """
    if os.uname().sysname == 'Darwin':
        return

    assert int(run("cat /proc/sys/vm/max_map_count")) >= 262144, \
        'the "vm.max_map_count" kernel parameter is too low, check readme'


def deploy(*args):
    """Run all the jobs in nomad."""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--no-secrets', action='store_false', dest='secrets')
    parser.add_argument('--no-checks', action='store_false', dest='checks')
    options = parser.parse_args(args)

    check_system_config()

    consul.set_kv('liquid_domain', config.liquid_domain)
    consul.set_kv('liquid_debug', 'true' if config.liquid_debug else 'false')
    consul.set_kv('liquid_http_protocol', config.liquid_http_protocol)

    if options.secrets:
        vault.ensure_engine()

    vault_secret_keys = [
        'liquid/liquid/core.django',
        'liquid/hoover/auth.django',
        'liquid/hoover/search.django',
        'liquid/hoover/search.postgres',
        'liquid/hoover/snoop.django',
        'liquid/hoover/snoop.postgres',
        'liquid/authdemo/auth.django',
        'liquid/nextcloud/nextcloud.admin',
        'liquid/nextcloud/nextcloud.uploads',
        'liquid/nextcloud/nextcloud.maria',
        'liquid/dokuwiki/auth.django',
        'liquid/nextcloud/auth.django',
        'liquid/rocketchat/auth.django',
        'liquid/hypothesis/auth.django',
        'liquid/hypothesis/hypothesis.secret_key',
        'liquid/hypothesis/hypothesis.postgres',
        'liquid/codimd/auth.django',
        'liquid/codimd/codimd.session',
        'liquid/codimd/codimd.postgres',
        'liquid/ci/vmck.django',
        'liquid/ci/drone.secret',
    ]
    core_auth_apps = list(CORE_AUTH_APPS)

    for job in config.enabled_jobs:
        vault_secret_keys += list(job.vault_secret_keys)
        core_auth_apps += list(job.core_auth_apps)

    if options.secrets:
        for path in vault_secret_keys:
            ensure_secret_key(path)

        if config.ci_enabled:
            vault.set('liquid/ci/drone.github', {
                'client_id': config.ci_github_client_id,
                'client_secret': config.ci_github_client_secret,
                'user_filter': config.ci_github_user_filter,
            })
            vault.set('liquid/ci/drone.docker', {
                'username': config.ci_docker_username,
                'password': config.ci_docker_password,
            })

    def start(job, hcl):
        log.info('Starting %s...', job)
        spec = nomad.parse(hcl)
        nomad.run(spec)
        job_checks = {}
        for service, checks in nomad.get_health_checks(spec):
            if not checks:
                log.warn(f'service {service} has no health checks')
                continue
            job_checks[service] = checks
        return job_checks

    jobs = [(job.name, get_job(job.template)) for job in config.enabled_jobs]

    ensure_secret('liquid/rocketchat/adminuser', lambda: {
        'username': 'rocketchatadmin',
        'pass': random_secret(64),
    })

    # Start liquid-core in order to setup the auth
    liquid_checks = start('liquid', dict(jobs)['liquid'])
    if options.checks:
        wait_for_service_health_checks({'core': liquid_checks['core']})

    if options.secrets:
        for app in core_auth_apps:
            log.info('Auth %s -> %s', app['name'], app['callback'])
            cmd = ['./manage.py', 'createoauth2app', app['name'], app['callback']]
            containers = docker.containers([('liquid_task', 'liquid-core')])
            container_id = first(containers, 'liquid-core containers')
            docker_exec_cmd = ['docker', 'exec', container_id] + cmd
            tokens = json.loads(run(docker_exec_cmd, shell=False))
            vault.set(app['vault_path'], tokens)

    # check if there are jobs to stop
    nomad_jobs = set(job['ID'] for job in nomad.jobs())
    jobs_to_stop = nomad_jobs.intersection(set(job.name for job in config.disabled_jobs))
    log.info(f'jobs to stop: {jobs_to_stop}')
    if jobs_to_stop:
        for job in jobs_to_stop:
            nomad.stop(job)
        wait_for_stopped_jobs(jobs_to_stop)

    # only start deps jobs + hoover
    hov_deps = hoover.Deps()
    deps_jobs = [(hov_deps.name, get_job(hov_deps.template))]

    health_checks = {}
    for job, hcl in deps_jobs:
        job_checks = start(job, hcl)
        health_checks.update(job_checks)

    # wait until all deps are healthy
    if options.checks:
        wait_for_service_health_checks(health_checks)

    # run the set password script
    if options.secrets:
        docker.exec_(f'hoover-deps:search-pg', 'sh', '/local/set_pg_password.sh')
        docker.exec_(f'hoover-deps:snoop-pg', 'sh', '/local/set_pg_password.sh')

    for job, hcl in jobs:
        job_checks = start(job, hcl)
        health_checks.update(job_checks)

    # Wait for everything else
    if options.checks:
        wait_for_service_health_checks(health_checks)

    log.info("Deploy done!")


def halt():
    """Stop all the jobs in nomad."""

    jobs = [j.name for j in config.all_jobs]
    for job in jobs:
        log.info('Stopping %s...', job)
        nomad.stop(job)


def gc():
    """Stop all jobs that should not be running in the current deploy configuration:
    - jobs from disabled applications.
    """
    stopped_jobs = []
    for job in config.disabled_jobs:
        nomad.stop(job.name)
        stopped_jobs.append(job.name)

    wait_for_stopped_jobs(stopped_jobs)


def nomadgc():
    """Remove dead jobs from nomad"""
    nomad.gc()


def nomad_address():
    """Print the nomad address."""

    print(nomad.get_address())


def alloc(job, group):
    """Print the ID of the current allocation of the job and group.

    :param job: the job identifier
    :param group: the group identifier
    """

    allocs = nomad.job_allocations(job)
    running = [
        a['ID'] for a in allocs
        if a['ClientStatus'] == 'running' and a['TaskGroup'] == group
    ]
    print(first(running, 'running allocations'))


def shell(name, *args):
    """Open a shell in a docker container tagged with liquid_task=`name`"""

    docker.shell(name, *args)


def dockerexec(name, *args):
    """Run `docker exec` in a container tagged with liquid_task=`name`"""

    docker.exec_(name, *args)


def getsecret(path=None):
    """Get a Vault secret"""

    if path:
        print(vault.read(path))

    else:
        for section in vault.list():
            for key in vault.list(section):
                print(f'{section}{key}')


def launchocr(*args):
    """Launch either a batch or a daily batch OCR process."""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name', help='collection name')
    parser.add_argument('--periodic', dest='periodic', help='cron expression')
    parser.add_argument('--workers', dest='workers', help='worker process count')
    parser.add_argument('--threads_per_worker', dest='threads_per_worker', help='default and max value is 4.')
    parser.add_argument('--nice', dest='nice', help='argument to `nice -n`.')
    options = parser.parse_args(args)

    collection_names = [c['name'] for c in config.snoop_collections]
    assert options.name in collection_names, 'unknown collection name: ' + options.name
    data_dir = Path(config.liquid_collections) / options.name / 'data'
    assert data_dir.is_dir(), \
        f'{data_dir} should be a directory where all collection data is stored.'

    hcl = get_job(config.templates / 'collection-ocr.nomad', vars(options))
    spec = nomad.parse(hcl)
    nomad.run(spec)
    log.info(f'Launched OCR job {spec["Name"]}')
