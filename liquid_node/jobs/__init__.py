import subprocess
import logging
import os
from pathlib import Path
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
        'wiki_js': {
            'org': 'liquidinvestigations',
            'local': os.path.join(config.liquidinvestigations_repos_path, 'wiki.js'),
            'target': '/wiki',
        },
    }

    for repo, repo_config in repos.items():
        key_repo = f"{repo_config['org']}_{repo}_repo"
        key_git = f"{repo_config['org']}_{repo}_git"
        key_mounted = f"{repo_config['org']}_{repo}_mounted"

        substitutions[key_repo] = ''
        substitutions[key_git] = ''
        substitutions[key_mounted] = ''
        if config.mount_local_repos:
            if Path(repo_config['local']).is_dir():
                substitutions[key_repo] = f"\"{repo_config['local']}:{repo_config['target']}\",\n"
                tag = subprocess.check_output(
                    f"git -C {repo_config['local']} describe  --tags --dirty --broken",
                    shell=True,
                ).decode('utf-8').strip()
                md5sum = subprocess.check_output(
                    f"git -C {repo_config['local']} diff HEAD | md5sum",
                    shell=True,
                ).decode('utf-8').strip()
                substitutions[key_git] = tag + md5sum
                substitutions[key_mounted] = 'true'
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
    try:
        return render(template, set_volumes_paths(substitutions))
    except Exception as e:
        log.exception(e)
        log.error('template %s failed to parse!!!', hcl_path)
        raise e


class Job:
    vault_secret_keys = ()
    core_oauth_apps = ()
    stage = 2
    generate_oauth2_proxy_cookie = False
    extra_secret_fn = None
    custom_homepage_config = None
