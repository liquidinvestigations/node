from .nomad import nomad
from .configuration import config
from .consul import consul
from .jobs import get_job, wait_for_stopped_jobs
from .process import run, run_fg
from .util import first, retry
from .docker import docker
from .vault import vault
from time import time, sleep
from collections import defaultdict
import click
import os
import logging
import json
import base64
import multiprocessing

log = logging.getLogger(__name__)

VAULT_SECRET_KEYS = [
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
    'liquid/ci/drone.rpc.secret',
]

CORE_AUTH_APPS = [
    {
        'name': 'authdemo',
        'vault_path': 'liquid/authdemo/auth.oauth2',
        'callback': f'{config.app_url("authdemo")}/oauth2/callback',
    },
    {
        'name': 'hoover',
        'vault_path': 'liquid/hoover/auth.oauth2',
        'callback': f'{config.app_url("hoover")}/oauth2/callback',
    },
    {
        'name': 'dokuwiki',
        'vault_path': 'liquid/dokuwiki/auth.oauth2',
        'callback': f'{config.app_url("dokuwiki")}/oauth2/callback',
    },
    {
        'name': 'rocketchat-authproxy',
        'vault_path': 'liquid/rocketchat/auth.oauth2',
        'callback': f'{config.app_url("rocketchat")}/oauth2/callback',
    },
    {
        'name': 'rocketchat-app',
        'vault_path': 'liquid/rocketchat/app.oauth2',
        'callback': f'{config.app_url("rocketchat")}/_oauth/liquid',
    },
    {
        'name': 'nextcloud',
        'vault_path': 'liquid/nextcloud/auth.oauth2',
        'callback': f'{config.app_url("nextcloud")}/oauth2/callback',
    },
    {
        'name': 'codimd-app',
        'vault_path': 'liquid/codimd/app.auth.oauth2',
        'callback': f'{config.app_url("codimd")}/auth/oauth2/callback',
    },
    {
        'name': 'codimd-authproxy',
        'vault_path': 'liquid/codimd/auth.oauth2',
        'callback': f'{config.app_url("codimd")}/oauth2/callback',
    },
    {
        'name': 'hypothesis',
        'vault_path': 'liquid/hypothesis/auth.oauth2',
        # the old auth proxy is still running for this service. new one:
        # 'callback': f'{config.app_url("hypothesis")}/oauth2/callback',
        'callback': f'{config.app_url("hypothesis")}/__auth/callback',
    },
]


@click.group()
def liquid_commands():
    pass


@liquid_commands.command()
def resources():
    """Get memory and CPU usage for the deployment"""

    def get_all_res():
        jobs = [nomad.parse(get_job(job.template)) for job in config.enabled_jobs]
        for spec in jobs:
            yield from nomad.get_resources(spec)

    total = defaultdict(int)
    for name, count, _type, res in get_all_res():
        for key in ['MemoryMB', 'CPU', 'EphemeralDiskMB']:
            if key not in res:
                continue
            if res[key] is None:
                raise RuntimeError("Please update Nomad to 0.9.3+")
            total[f'{_type} {key}'] += res[key] * count

    print('Resource requirement totals: ')
    for key, value in sorted(total.items()):
        print(f'  {key}: {value}')


def random_secret(bits=256):
    """ Generate a crypto-quality 256-bit random string. """
    return str(base64.b16encode(os.urandom(int(bits / 8))), 'latin1').lower()


def ensure_secret(path, get_value):
    if not vault.read(path) or set(vault.read(path).keys()) != set(get_value()):
        log.info(f"Generating value for {path}")
        vault.set(path, get_value())


def ensure_secret_key(path):
    ensure_secret(path, lambda: {'secret_key': random_secret()})


def wait_for_service_health_checks(health_checks):
    """Waits health checks to become green for green_count times in a row. """

    if not health_checks:
        return

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
    log.info(f"Waiting for health checks on {len(services)} services")

    greens = 0
    timeout = t0 + config.wait_max + config.wait_interval * config.wait_green_count
    last_checks = set(get_checks())
    log_checks(last_checks, print_passing=False)
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
            log.info(f"Checks green for {len(services)} services after {time() - t0:.02f}s")
            return

        # No chance to get enough greens
        no_chance_timestamp = timeout - config.wait_interval * config.wait_green_count
        if greens == 0 and time() >= no_chance_timestamp:
            break

    log_checks(checks, as_error=True)
    msg = f'Checks are failed after {time() - t0:.02f}s.'
    raise RuntimeError(msg)


def check_system_config():
    """Raises errors if the system is improperly configured.
    This checks if elasticsearch will accept our
    vm.max_map_count kernel parameter value.
    """
    if os.uname().sysname == 'Darwin':
        return

    assert int(run("cat /proc/sys/vm/max_map_count", shell=True)) >= 262144, \
        'the "vm.max_map_count" kernel parameter is too low, check readme'


def start_job(job, hcl):
    log.debug('Starting %s...', job)
    spec = nomad.parse(hcl)
    nomad.run(spec)
    job_checks = {}
    for service, checks in nomad.get_health_checks(spec):
        if not checks:
            log.warn(f'service {service} has no health checks')
            continue
        job_checks[service] = checks
    return job_checks


def create_oauth2_app(app):
    log.info('Auth %s -> %s', app['name'], app['callback'])
    cmd = ['./manage.py', 'createoauth2app', app['name'], app['callback']]
    output = retry()(docker.exec_)('liquid:core', *cmd)
    tokens = json.loads(output)
    vault.set(app['vault_path'], tokens)
    return app['name']


def populate_secrets_pre(vault_secret_keys):
    """Sets a secrets for every path given and start liquid-core.

    The function sets a secret for every path given (the secrets stored in vault_secret_keys are 256 bits
    whereas the secrets for cookies are 64 bits long).

    Args:
        vault_secrets_keys: A list of paths for which a secret is needed.

    Returns:
        None
    """

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
        ensure_secret('liquid/ci/drone.secret.2', lambda: {
            'secret_key': random_secret(128),
        })

    ensure_secret('liquid/rocketchat/adminuser', lambda: {
        'username': 'rocketchatadmin',
        'pass': random_secret(64),
    })

    for name in config.ALL_APPS:
        ensure_secret(f'liquid/{name}/cookie', lambda: {
            'cookie': random_secret(64),
        })


def populate_secrets_post(core_auth_apps):
    """Sets up oauth2 app logins.

    Creates OAuth2 entries for every app. If self-hosted continuous integration
    is enabled, then the client id and secret are added to vault.

    Args:
        core_auth_apps: A list of dictionary which contains app's name, vault_path and callback to create
                        Oauth2 entries.
    Returns:
        None
    """
    # Create the OAuth2 callbacks for apps. This is really slow, so do them all
    # in parallel...
    with multiprocessing.Pool(3) as p:
        for app_name in p.imap_unordered(create_oauth2_app, core_auth_apps):
            log.debug('auth done: ' + app_name)
    log.info('secrets done.')


@liquid_commands.command()
@click.option('--no-secrets', 'secrets', is_flag=True, default=True)
@click.option('--no-checks', 'checks', is_flag=True, default=True)
# @click.argument('args', nargs= -1)
def deploy(secrets, checks):
    """Run all the jobs in nomad."""
    check_system_config()
    consul.set_kv('liquid_domain', config.liquid_domain)
    consul.set_kv('liquid_debug', 'true' if config.liquid_debug else 'false')
    consul.set_kv('liquid_http_protocol', config.liquid_http_protocol)

    if secrets:
        vault.ensure_engine()

    vault_secret_keys = list(VAULT_SECRET_KEYS)
    core_auth_apps = list(CORE_AUTH_APPS)

    for job in config.enabled_jobs:
        vault_secret_keys += list(job.vault_secret_keys)
        core_auth_apps += list(job.core_auth_apps)

    jobs = [(job.name, (job.stage, get_job(job.template))) for job in config.enabled_jobs]

    if secrets:
        populate_secrets_pre(vault_secret_keys)

    # check if there are jobs to stop
    nomad_jobs = set(job['ID'] for job in nomad.jobs())
    jobs_to_stop = nomad_jobs.intersection(set(job.name for job in config.disabled_jobs))
    if jobs_to_stop:
        log.info(f'Stopping jobs: {jobs_to_stop}')
    if jobs_to_stop:
        for job in jobs_to_stop:
            nomad.stop(job)
        wait_for_stopped_jobs(jobs_to_stop)

    # Deploy everything in stages
    health_checks = {}
    for stage in range(5):
        stage_jobs = [(n, t[1]) for n, t in jobs if t[0] == stage]
        log.info(f'Deploy stage #{stage}, starting jobs: {[j[0] for j in stage_jobs]}')

        for name, template in stage_jobs:
            job_checks = start_job(name, template)
            health_checks.update(job_checks)

        # wait until all deps are healthy
        if stage_jobs and checks:
            wait_for_service_health_checks(health_checks)

        if stage == 0:
            if secrets:
                populate_secrets_post(core_auth_apps)

        if stage == 1:
            # run the set password script
            if secrets:
                if config.is_app_enabled('hoover'):
                    retry()(docker.exec_)('hoover-deps:search-pg', 'sh', '/local/set_pg_password.sh')
                    retry()(docker.exec_)('hoover-deps:snoop-pg', 'sh', '/local/set_pg_password.sh')

    log.info("Deploy done!")


@liquid_commands.command()
def halt():
    """Stop all the jobs in nomad."""

    jobs = [j.name for j in config.all_jobs]
    for job in jobs:
        log.info('Stopping %s...', job)
        nomad.stop(job)

    wait_for_stopped_jobs(jobs)


@liquid_commands.command()
def nomadgc():
    """Remove dead jobs from nomad"""
    nomad.gc()


@liquid_commands.command()
def nomad_address():
    """Print the nomad address."""

    print(nomad.get_address())


@liquid_commands.command()
@click.argument('job')
@click.argument('group')
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


@liquid_commands.command(context_settings={"ignore_unknown_options": True})
@click.argument('name')
@click.argument('args', nargs=-1, type=str)
def shell(name, args):
    """Open a shell in a docker container addressed as JOB:TASK"""
    docker.shell(name, *args)


@liquid_commands.command(context_settings={"ignore_unknown_options": True})
@click.argument('name')
@click.argument('args', nargs=-1, type=str)
def dockerexec(name, args):
    """Run `nomad alloc exec` in a container addressed as JOB:TASK"""
    run_fg(docker.exec_command(name, *args, tty=False), shell=False)


@liquid_commands.command()
@click.argument('path', required=False)
def getsecret(path=None):
    """Get a Vault secret"""

    if path:
        print(vault.read(path))

    else:
        for section in vault.list():
            for key in vault.list(section):
                print(f'{section}{key}')
