import logging
import os
from pathlib import Path

import jinja2

log = logging.getLogger(__name__)
TEMPLATES = Path(__file__).parent.parent.parent.resolve() / 'templates'


def set_collection_defaults(name, settings):
    """Sets the collection job default options

    :param name: collection name
    :param settings: dictionary containing the collection job options
    """

    settings['name'] = name
    settings.setdefault('workers', '1')
    settings.setdefault('sync', 'false')


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
    substitutions['consul_socket'] = os.path.realpath(config.consul_socket)
    substitutions['consul_url'] = config.consul_url

    substitutions['https_enabled'] = config.https_enabled
    if config.https_enabled:
        substitutions['liquid_https_port'] = config.liquid_https_port
        substitutions['acme_email'] = config.https_acme_email
        substitutions['acme_caServer'] = config.https_acme_caServer

    repos = {
        'snoop2': {
            'org': 'hoover',
            'local': os.path.join(config.hoover_repos_path, 'snoop2'),
            'target': '/opt/hoover/snoop'
        },
        'search': {
            'org': 'hoover',
            'local': os.path.join(config.hoover_repos_path, 'search'),
            'target': '/opt/hoover/search'
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


def get_collection_job(name, settings, template='collection.nomad'):
    """Return the collection job description

    :param name: collection name
    :param settings: dictionary containing the collection job options
    :returns: collection job description
    :rtype: str
    """

    from ..configuration import config

    substitutions = dict(settings)
    set_collection_defaults(name, substitutions)

    return get_job(config.templates / template, substitutions)


def render(template, subs):
    from ..configuration import config

    env = jinja2.Environment(
        variable_start_string="${",
        variable_end_string="}",
        loader=jinja2.FileSystemLoader(str(config.templates)),
    )
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


class Job:
    vault_secret_keys = ()
    core_auth_apps = ()
