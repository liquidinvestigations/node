import logging
import os
from pathlib import Path
from time import time, sleep
from ..docker import docker

import jinja2


log = logging.getLogger(__name__)
TEMPLATES = Path(__file__).parent.parent.parent.resolve() / 'templates'


def set_volumes_paths(substitutions={}):
    """Sets the volumes paths in the job options

    :param substitutions: dictionary containing the job options
    :returns: the job options
    :rtype: dict
    """

    from ..configuration import config

    substitutions['config'] = config
    substitutions['liquid_domain'] = config.liquid_domain
    substitutions['liquid_volumes'] = config.liquid_volumes
    substitutions['liquid_collections'] = config.liquid_collections
    substitutions['liquid_http_port'] = config.liquid_http_port
    substitutions['liquid_2fa'] = config.liquid_2fa
    substitutions['check_interval'] = config.check_interval
    substitutions['check_timeout'] = config.check_timeout
    substitutions['consul_url'] = config.consul_url

    substitutions['exec_command'] = docker.exec_command_str

    substitutions['https_enabled'] = config.https_enabled
    if config.https_enabled:
        substitutions['liquid_https_port'] = config.liquid_https_port
        substitutions['acme_email'] = config.https_acme_email
        substitutions['acme_caServer'] = config.https_acme_caServer

    repos = {
        'snoop2': {
            'org': 'hoover',
            'local': os.path.join(config.liquidinvestigations_repos_path, 'hoover-snoop2'),
            'target': '/opt/hoover/snoop'
        },
        'search': {
            'org': 'hoover',
            'local': os.path.join(config.liquidinvestigations_repos_path, 'hoover-search'),
            'target': '/opt/hoover/search'
        },
        'ui_src': {
            'org': 'hoover',
            'local': os.path.join(config.liquidinvestigations_repos_path, 'hoover-ui/src'),
            'target': '/opt/hoover/ui/src'
        },
        'ui_pages': {
            'org': 'hoover',
            'local': os.path.join(config.liquidinvestigations_repos_path, 'hoover-ui/pages'),
            'target': '/opt/hoover/ui/pages'
        },
        'ui_styles': {
            'org': 'hoover',
            'local': os.path.join(config.liquidinvestigations_repos_path, 'hoover-ui/styles'),
            'target': '/opt/hoover/ui/styles'
        },
        'core': {
            'org': 'liquidinvestigations',
            'local': os.path.join(config.liquidinvestigations_repos_path, 'core'),
            'target': '/app'
        },
        'authproxy': {
            'org': 'liquidinvestigations',
            'local': os.path.join(config.liquidinvestigations_repos_path, 'authproxy'),
            'target': '/app'
        },
        'h_h': {
            'org': 'hypothesis',
            'local': os.path.join(config.liquidinvestigations_repos_path, 'hypothesis-h/h'),
            'target': '/var/lib/hypothesis/h',
        },
        'h_conf': {
            'org': 'hypothesis',
            'local': os.path.join(config.liquidinvestigations_repos_path, 'hypothesis-h/conf'),
            'target': '/var/lib/hypothesis/conf',
        },
        'codimd_server': {
            'org': 'liquidinvestigations',
            'local': os.path.join(config.liquidinvestigations_repos_path, 'codimd-server'),
            'target': '/app',
        },
        'dokuwiki': {
            'org': 'liquidinvestigations',
            'local': os.path.join(config.liquidinvestigations_repos_path, 'liquid-dokuwiki'),
            'target': '/liquid',
        },
    }

    for repo, repo_config in repos.items():
        key = f"{repo_config['org']}_{repo}_repo"

        substitutions[key] = ''
        if config.mount_local_repos:
            if Path(repo_config['local']).is_dir():
                substitutions[key] = f"\"{repo_config['local']}:{repo_config['target']}\",\n"
            else:
                log.warn(f'Invalid repo path "{repo_config["local"]}"')

    return substitutions


def render(template, subs):
    from ..configuration import config

    env = jinja2.Environment(
        variable_start_string="${",
        variable_end_string="}",
        loader=jinja2.FileSystemLoader(str(config.templates)),
    )
    env.globals['int'] = int
    env.globals['max'] = max
    return env.from_string(template).render(subs)


def get_job(hcl_path, substitutions={}):
    """Return the job description generated from the given template

    :param hcl_path: the path to the hcl template file
    :param substitutions: dictionary containing the job options
    :returns: the job description
    :rtype: str
    """
    with hcl_path.open() as job_file:
        template = job_file.read()

    output = render(template, set_volumes_paths(substitutions))
    return output


def wait_for_stopped_jobs(stopped_jobs):
    from liquid_node.configuration import config
    from liquid_node.nomad import nomad

    if not stopped_jobs:
        return

    stopped_jobs = list(stopped_jobs)
    log.info('Waiting for the following jobs to die: ' + ', '.join(stopped_jobs))
    timeout = time() + config.wait_max

    while stopped_jobs and time() < timeout:
        sleep(config.wait_interval)

        nomad_jobs = {job['ID']: job for job in nomad.jobs() if job['ID'] in stopped_jobs}
        for job_name in stopped_jobs:
            if job_name not in nomad_jobs or nomad_jobs[job_name]['Status'] == 'dead':
                stopped_jobs.remove(job_name)
                log.info(f'Job {job_name} is dead')

    if stopped_jobs:
        raise RuntimeError(f'The following jobs are still running: {stopped_jobs}')


class Job:
    vault_secret_keys = ()
    core_auth_apps = ()
    stage = 2
