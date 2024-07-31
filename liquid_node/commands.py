import subprocess
import sys
from time import time, sleep
import datetime
from collections import defaultdict
from contextlib import closing
import click
import os
import logging
import json
import multiprocessing
import socket

from .nomad import nomad
from .configuration import config
from .consul import consul
from .jobs import get_job
from .process import run, run_fg
from .util import first, retry, random_secret
from .docker import docker
from .vault import vault
from .jsonapi import JsonApi

log = logging.getLogger(__name__)


@click.group()
def liquid_commands():
    pass


def check_resources():
    enabled_app_count = len(list(c for c in config.liquid_apps if c['enabled']))
    cpu_count_req = 2 + int(
        (enabled_app_count * 0.5 + config.total_snoop_worker_count * 0.8)
    )

    AVAILABLE_MEMORY_SCALE = 0.95
    SMALL_CPU_COUNT_IGNORE = 16
    EXTRA_REQ = {
        "CPU": 0,
        "MemoryMB": 0,
        "EphemeralDiskMB": 10000,
        "cpu_count": cpu_count_req,
        'node_count': 1,
    }

    def get_all_res():
        specs = [nomad.parse(get_job(job.template)) for job in config.enabled_jobs]
        # Check all config files have correct filenames
        for spec, job in zip(specs, config.enabled_jobs):
            template_filename = os.path.splitext(os.path.basename(job.template))[0]
            nomad_job_name = spec['Name']
            python_job_name = job.name

            if template_filename != nomad_job_name \
                    or template_filename != python_job_name \
                    or nomad_job_name != python_job_name:
                log.error("PROGRAMMER ERROR: job names do not match.")
                log.error("template filename: %s", template_filename)
                log.error("nomad job name: %s", nomad_job_name)
                log.error("python job name: %s", python_job_name)
                log.error("Please fix the code so all above are matching. Thank you.")
                raise RuntimeError("mismatching job names")
        for spec in specs:
            yield from nomad.get_resources(spec)

    total = defaultdict(int)
    req = defaultdict(int)
    for name, count, _type, res in get_all_res():
        for key in EXTRA_REQ.keys():
            if key not in res:
                continue
            if res[key] is None:
                raise RuntimeError("Please update Nomad to 0.9.3+")
            total[f'{_type} {key}'] += res[key] * count
            req[key] += res[key] * count

    for key in EXTRA_REQ:
        req[key] += EXTRA_REQ[key]
        total[f'extra {key}'] += EXTRA_REQ[key]

    avail = nomad.get_available_resources()
    log.debug('Resource available (total): ')
    for key, value in sorted(avail.items()):
        log.debug(f'  {key: <30}: {value:,}')

    if avail['cpu_count'] <= SMALL_CPU_COUNT_IGNORE:
        if req['cpu_count'] > avail['cpu_count']:
            req['cpu_count'] = avail['cpu_count']
            log.debug('lowering requirements for small cluster (<%s cores) to cpu_count = %s',
                      SMALL_CPU_COUNT_IGNORE, avail['cpu_count'])

    log.debug('Resource requirements (split): ')
    for key, value in sorted(total.items()):
        log.debug(f'  {key: <30}: {value:,}')

    log.info('Resource requirements (required / available): ')
    for key, value in sorted(req.items()):
        if key in ['MemoryMB', 'CPU']:
            avail[key] = int(avail[key] * AVAILABLE_MEMORY_SCALE / 100) * 100
        log.info(f'  {key: <30}: {value:,} / {avail[key]:,}')
        if req[key] > avail[key]:
            log.error('not enough %s: %s / %s', key, req[key], avail[key])
            sys.exit(1)


def check_port(ip, port):
    '''Checks if a given port for an IP is open.'''
    with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as sock:
        sock.settimeout(2)
        result = sock.connect_ex((ip, port))
        if result == 0:
            return True
        else:
            return False


def add_cron_job(cron_command):
    try:
        result = subprocess.run(['crontab', '-l'], capture_output=True, text=True, check=True)
        if result.stdout and 'purge-volumes.sh' not in result.stdout:
            cron_jobs = result.stdout.strip() + '\n' + cron_command + '\n'
        elif not result.stdout:
            cron_jobs = cron_command + '\n'
        else:
            log.info('Cronjob already exists. No new cronjob added.')
            return
    except subprocess.CalledProcessError as e:
        log.warning(f'Listing crontab exited with a non-zero exit code: {e}. Trying to install new crontab.')
        cron_jobs = cron_command + '\n'
    try:
        subprocess.run(['crontab', '-'], input=cron_jobs, text=True, capture_output=True)
    except subprocess.CalledProcessError as e:
        log.error(f'Could not add cronjob: {e}')
        return
    log.info('Added cronjob for demo mode.')


def remove_cron_job(script_name):
    # Step 1: Retrieve current list of cron jobs
    process = subprocess.run(['crontab', '-l'], capture_output=True, text=True, check=True)
    cron_jobs_to_keep = []
    if not process.stdout:
        log.error('Could not find any cronjobs in crontab.')
        return
    for line in process.stdout.splitlines():
        if script_name in line:
            continue
        else:
            cron_jobs_to_keep.append(line)

    new_cron_content = '\n'.join(cron_jobs_to_keep)
    new_cron_content = new_cron_content + '\n'
    try:
        process = subprocess.run(['crontab', '-'], input=new_cron_content, text=True, capture_output=True)
    except subprocess.CalledProcessError as e:
        log.error(f'Could write new crontab: {e}')
        return


@liquid_commands.command()
def resources():
    """Get memory and CPU usage for the deployment"""
    check_resources()


@liquid_commands.command()
def health_check():
    """Look at all jobs for many restart events, and print the most recent error."""
    printed_something = False

    job_checks = {}
    job_names = []
    for job in config.enabled_jobs:
        spec = nomad.parse(get_job(job.template))
        printed_something |= bool(nomad.check_events_and_logs(job.name))
        for service, checks in nomad.get_health_checks_from_spec(spec):
            if not checks:
                log.warn(f'service {service} has no health checks')
                continue
            job_checks[service] = checks
            job_names.append(job.name)
    printed_something |= nomad.wait_for_service_health_checks(consul, job_names, job_checks, nowait=True)

    if printed_something:
        log.error('Problems detected; see logs above.')
        sys.exit(1)
    else:
        log.info('No problems detected.')


@liquid_commands.command()
def dump_healthcheck_info():
    import json

    def _get_check_entries():
        for job in config.enabled_jobs:
            spec = nomad.parse(get_job(job.template))
            for service, checks in nomad.get_health_checks_from_spec(spec):
                for check in checks:
                    yield {
                        "app": job.app or 'None',
                        "stage": str(job.stage) or 'None',
                        "job": job.name,
                        "service": service,
                        "check": check,
                    }
    print(json.dumps(sorted(_get_check_entries(), key=lambda d: tuple(d.items())), indent=2))


def all_images():
    """Get all docker images to pull for enabled docker jobs."""

    total = set()
    jobs = [nomad.parse(get_job(job.template)) for job in config.enabled_jobs]
    for spec in jobs:
        for image in nomad.get_images(spec):
            if image is not None and image != 'None':
                total |= set([image])
    return total


def check_system_config():
    """Raises errors if the system is improperly configured.
    This checks if elasticsearch will accept our
    vm.max_map_count kernel parameter value.
    """
    if os.uname().sysname == 'Darwin':
        return

    assert int(run("cat /proc/sys/vm/max_map_count", shell=True)) >= 262144, \
        'the "vm.max_map_count" kernel parameter is too low, check readme'

    check_resources()


def start_job(job, hcl, check_batch_jobs=False):
    log.debug('Starting %s...', job)
    spec = nomad.parse(hcl, replace_images=True)
    nomad.run(spec, check_batch_jobs)
    job_checks = {}
    for service, checks in nomad.get_health_checks_from_spec(spec):
        if not checks:
            log.warn(f'service {service} has no health checks')
            continue
        job_checks[service] = checks
    return job_checks


def create_oauth2_app(app):
    log.info('Auth %s -> %s', app['name'], app['callback'])
    subdomain = app.get('subdomain', app.get('name'))
    cb = config.app_url(subdomain) + app['callback']
    cmd = ['./manage.py', 'createoauth2app', app['name'], cb]
    if 'noskip' in app:
        cmd.append('--noskip')
    if 'algo' in app:
        cmd.append(f'--algo={app["algo"]}')

    output = retry()(docker.exec_)('liquid:core', *cmd)
    tokens = json.loads(output)
    vault.set(app['vault_path'], tokens)
    return app['name']


def populate_secrets_pre(vault_secret_keys, core_auth_cookies, extra_fns):
    """Sets a secrets for every path given and start liquid-core.

    The function sets a secret for every path given (the secrets stored in vault_secret_keys are 256 bits
    whereas the secrets for cookies are 64 bits long).

    Args:
        vault_secrets_keys: A list of paths for which a secret is needed.
        core_auth_cookies: A list of names for special auth proxy cookie secrets
        extra_fns: A list of callables that will generate extra secrets

    Returns:
        None
    """

    for path in vault_secret_keys:
        log.debug('checking secret key: %s', path)
        vault.ensure_secret_key(path)

    for fn in extra_fns:
        if fn:
            fn(vault, config, random_secret)

    for name in core_auth_cookies:
        vault.ensure_secret(f'liquid/{name}/cookie', lambda: {
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


def _update_image(name):
    """Runs `docker pull` and checks if the image digest changed.

    The arguments are passed through this function into the results for
    collecting after using multiprocessing.

    Returns: (name, changed)."""

    if not name or name == 'None':
        return None, None

    old = docker.image_digest(name)
    for _ in range(3):
        new = docker.pull(name, force=True)
        if new:
            break
        time.sleep(5)

    return name, old != new


def _update_images():
    """Update all docker images in this list, running a few in parallel."""

    any_new = False

    def comment(name, new):
        nonlocal any_new
        if new:
            log.info(f"Downloaded new Docker image for {name}  - {docker.image_size(name)}")
        elif name:
            log.debug(f"Docker image is up to date for {name}  - {docker.image_size(name)}")
        else:
            log.debug("found null")
            return

        any_new |= new

    t0 = time()
    log.info("Downloading docker images...")

    images = set(all_images())
    with multiprocessing.Pool(6) as p:
        for name, new in p.imap_unordered(_update_image, images):
            comment(name, new)

    log.info(f"All {len(images)} images are up to date, took {time()-t0:.02f}s")
    return any_new


@liquid_commands.command()
@click.option('--no-update-images', 'update_images', is_flag=True, default=True)
@click.option('--no-secrets', 'secrets', is_flag=True, default=True)
@click.option('--no-checks', 'checks', is_flag=True, default=True)
@click.option('--no-resource-checks', 'resource_checks', is_flag=True, default=True)
@click.option('--new-images-only', 'new_images_only', is_flag=True, default=False)
def deploy(update_images, secrets, checks, resource_checks, new_images_only):
    """Run all the jobs in nomad."""
    deploy_t0 = int(time())

    # Inject the healthcheck info on the config object.
    config.liquid_core_healthcheck_info = subprocess.check_output(
        './liquid dump-healthcheck-info', shell=True,
    ).decode('ascii')

    if resource_checks:
        check_system_config()
    consul.set_kv('liquid_domain', config.liquid_domain)
    consul.set_kv('liquid_debug', 'true' if config.liquid_debug else 'false')
    consul.set_kv('liquid_http_protocol', config.liquid_http_protocol)

    if update_images:
        if not _update_images():
            if new_images_only:
                log.warning('No new images and --new-images-only was set; skipping deploy')
                return

    if secrets:
        vault.ensure_engine()

    vault_secret_keys = list()
    core_auth_apps = list()
    core_auth_cookies = list()
    extra_secret_fns = list()

    for job in config.enabled_jobs:
        vault_secret_keys += list(job.vault_secret_keys)
        core_auth_apps += list(job.core_oauth_apps)
        if job.generate_oauth2_proxy_cookie:
            core_auth_cookies.append(job.name)
        if job.extra_secret_fn:
            extra_secret_fns.append(job.extra_secret_fn)

    if secrets:
        populate_secrets_pre(vault_secret_keys, core_auth_cookies, extra_secret_fns)

    jobs = [(job.name, (job.stage, get_job(job.template))) for job in config.enabled_jobs]

    # check if there are jobs to stop
    nomad_jobs = set(job['ID'] for job in nomad.jobs())
    jobs_to_stop = nomad_jobs.intersection(set(job.name for job in config.disabled_jobs))
    nomad.stop_and_wait(jobs_to_stop, nowait=not checks)

    # Deploy everything in stages
    health_checks = {}
    max_stage = max(j.stage for j in config.enabled_jobs)
    for stage in range(max_stage + 1):
        stage_jobs = [(n, t[1]) for n, t in jobs if t[0] == stage]
        if not stage_jobs:
            continue
        log.info(f'Deploy stage #{stage}, starting jobs: {[j[0] for j in stage_jobs]}')

        for name, template in stage_jobs:
            job_checks = start_job(name, template, checks)
            health_checks.update(job_checks)

        # wait until all deps are healthy
        if stage_jobs and checks:
            job_names = [j[0] for j in stage_jobs]
            nomad.wait_for_service_health_checks(consul, job_names, health_checks, deploy_t0)

        if stage == 0:
            if secrets:
                populate_secrets_post(core_auth_apps)
            ports = list(config.PORT_MAP.items())
            # get ip from nomad url
            ip = config.nomad_url.split('/')[2].split(':')[0]
            log.info('Checking ports for load balancer...')
            # check if all specified ports (in the config) are open
            for port in ports:
                if not check_port(ip, port[1]):
                    log.error(f'Fabio port {port[1]} ({port[0]}) is not open! Check for possible conflicts.')
            log.info('Check done!')

        if stage == 1:
            # run the set password script
            if secrets:
                if config.is_app_enabled('hoover'):
                    retry()(docker.exec_)('hoover-deps:search-pg', 'sh', '/local/set_pg_password.sh')
                    retry()(docker.exec_)('hoover-deps:snoop-pg', 'sh', '/local/set_pg_password.sh')
                if config.is_app_enabled('codimd'):
                    retry()(docker.exec_)('codimd-deps:postgres', 'sh', '/local/set_pg_password.sh')
                if config.is_app_enabled('wikijs'):
                    retry()(docker.exec_)('wikijs-deps:wikijs-pg', 'sh', '/local/set_pg_password.sh')

    # finally, reset the liquid-core health checks
    reset_cmd = ['./manage.py', 'resethealthchecks']
    retry()(docker.exec_)('liquid:core', *reset_cmd)

    log.info("Deploy done! Elapsed: %s", str(datetime.timedelta(seconds=int((time() - deploy_t0)))))


@liquid_commands.command()
def halt():
    """Stop all the jobs in nomad."""

    jobs = [j.name for j in config.all_jobs]
    nomad.stop_and_wait(jobs)


@liquid_commands.command()
def initialize_demo():
    """Initialize crontab for demo mode."""
    if not config.hoover_demo_mode:
        log.error('Demo mode disabled in liquid.ini. Exiting.')
        return
    hours = config.hoover_demo_mode_interval // 60
    if not config.liquid_volumes:
        log.error('Volume path not specified in liquid.ini. Please set it before initializing demo mode.')
        return
    add_cron_job(f'0 */{hours} * * * {config.root}/scripts/purge-volumes.sh {config.liquid_volumes}')
    try:
        subprocess.run([f'{config.root}/scripts/purge-volumes.sh', f'{config.liquid_volumes}'], check=True)
    except subprocess.CalledProcessError as e:
        log.error(f'Error initializing demo mode: {e}')
        return
    try:
        open(f'{config.root}/.demo_mode', 'x')
    except FileExistsError:
        log.error('The .demo_mode file exists. Is demo mode already enabled? If not delete the file and try again.')
        return
    log.info('Initialized demo. Added cronjob and hidden .demo_mode file.')


@liquid_commands.command()
def stop_demo():
    """Stop demo mode and remove crontab and hidden file."""
    if config.hoover_demo_mode:
        log.error('Demo mode enabled in liquid.ini. Exiting.')
        return
    hidden_file_path = f'{config.root}/.demo_mode'
    if os.path.exists(hidden_file_path):
        os.remove(hidden_file_path)
        log.warning('Removed hidden .demo_mode file.')
    else:
        log.warning('Hidden .demo_mode file not found.')
    remove_cron_job('purge-volumes.sh')
    log.info('Removed cronjob.')
    log.info('Stopped demo successfully.')


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


@liquid_commands.command()
def remove_last_es_data_node():
    """Send request to deactivate last Elasticsearch data node."""

    RETRY_COUNT = 120
    assert config.elasticsearch_data_node_count >= 1

    es_node_name = 'data-' + str(config.elasticsearch_data_node_count - 1)
    data_dir = config.liquid_volumes + "/hoover/es/" + es_node_name

    es = JsonApi(f'http://{nomad.get_address()}:{config.port_lb}/_es')
    es_health_url = '/_cluster/health?wait_for_status=yellow&timeout=60s&wait_for_no_relocating_shards=true&wait_for_no_initializing_shards=true&wait_for_active_shards=all'  # noqa: E501
    assert not es.get(es_health_url)['timed_out'], 'es not in a healthy state yet'

    log.info('Initial doc counts per node: ' + str({v['name']: v['indices']['docs']['count'] for v in es.get('/_nodes/stats/indices')['nodes'].values()}))  # noqa: E501
    log.info('Adding transient exclude rule for ' + es_node_name)
    req_data = {"transient": {"cluster.routing.allocation.exclude._name": es_node_name,
                              "cluster.routing.allocation.enable": "all",
                              "indices.recovery.max_bytes_per_sec": "80mb",
                              "indices.recovery.concurrent_streams": 3,
                              "cluster.routing.allocation.node_concurrent_recoveries": 3,
                              "cluster.routing.allocation.cluster_concurrent_rebalance": 3}}
    resp = es.put('/_cluster/settings', data=req_data)
    assert resp['acknowledged'], 'bad response from es'
    for i in range(RETRY_COUNT):
        try:
            resp = es.get(es_health_url)
            if resp['timed_out']:
                log.info(f'timed out minute {i+1}/{RETRY_COUNT}')
                sleep(10)
                continue
            resp = es.get('/_nodes/stats/indices')
            doc_count, doc_size = 0, 0
            for node in resp['nodes'].values():
                if node['name'] != es_node_name:
                    continue
                else:
                    doc_count = node['indices']['docs']['count']
                    doc_size = node['indices']['store']['size_in_bytes']
                    doc_size_mb = str(int(doc_size / 2 ** 20)) + " MB"
            if doc_count > 0 or doc_size > 0:
                log.info(f'node still has {doc_count} documents, in total {doc_size_mb}, retry {i+1}/{RETRY_COUNT}')  # noqa: E501
                sleep(60)
                continue
            else:
                log.info("Node has no documents remaining!")
                break
        except Exception as e:
            log.exception(e)
            sleep(60)
    log.info('Final doc counts per node: '
             + str({v['name']: v['indices']['docs']['count']
                    for v in es.get('/_nodes/stats/indices')['nodes'].values()}))
    log.warning("!!! 3 manual steps remaining !!!")
    log.warning(f"- Decrement `elasticsearch_data_node_count` in `liquid.ini` (set = {config.elasticsearch_data_node_count - 1})")  # noqa: E501
    log.warning("- Run: `./liquid deploy`")
    log.warning("- Delete the directory: " + data_dir)


@liquid_commands.command()
@click.option('--search-count', 'search_count', type=int, default=80)
@click.option('--max-concurrent', 'max_concurrent', type=int, default=27)
@click.option('--path', 'path', type=click.Path(exists=False), default='./plot-search-time.png')
def plot_search(search_count, max_concurrent, path):
    from .hoover_search_benchmark import plot
    plot(search_count, max_concurrent, path)


@liquid_commands.command()
@click.option('--prefix', 'prefix', type=str, default='')
def show_docker_pull_commands(prefix):
    images = set(all_images())
    if None in images:
        images.remove(None)
    if 'None' in images:
        images.remove('None')
    images = sorted(images)

    if prefix:
        images = [prefix + '/' + str(i) if str(i).count('/') <= 1 else i for i in images]

    echo_str = "\n".join(' echo ' + i for i in images)
    print(f'\n\n( (\n{echo_str}\n) | xargs -n1 -P8 docker pull )\n')


@liquid_commands.command()
def remove_dead_nodes():
    removed = False
    for member in nomad.get('nodes'):
        if member['Status'] != 'ready':
            removed = True
            log.info(f'Removing node: {member["Name"]} from nomad!')
            nomad.post(f'node/{member["ID"]}/purge')

    for member in consul.get('agent/members'):
        if member['Status'] != 1:
            removed = True
            log.info(f'Removing node: {member["Name"]} from consul!')
            consul.put(f'agent/force-leave/{member["Name"]}?prune')

    if not removed:
        log.info('No dead nodes to remove!')
