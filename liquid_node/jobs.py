import os
from string import Template

from .configuration import config


def set_collection_defaults(name, settings):
    """Sets the collection job default options

    :param name: collection name
    :param settings: dictionary containing the collection job options
    """

    settings['name'] = name
    settings.setdefault('workers', '1')


def set_volumes_paths(substitutions={}):
    """Sets the volumes paths in the job options

    :param substitutions: dictionary containing the job options
    :returns: the job options
    :rtype: dict
    """

    substitutions['liquid_domain'] = config.liquid_domain
    substitutions['liquid_volumes'] = config.liquid_volumes
    substitutions['liquid_collections'] = config.liquid_collections
    substitutions['liquid_http_port'] = config.liquid_http_port

    repos_path = os.path.join(os.path.realpath(os.path.dirname(__file__)), 'repos')
    repos = {
        'snoop2': {
            'org': 'hoover',
            'local': os.path.join(repos_path, 'hoover'),
            'target': '/opt/hoover/snoop'
        },
        'search': {
            'org': 'hoover',
            'local': os.path.join(repos_path, 'hoover'),
            'target': '/opt/hoover/search'
        },
        'core': {
            'org': 'liquidinvestigations',
            'local': os.path.join(repos_path, 'liquidinvestigations'),
            'target': '/app'
        }
    }

    if config.hoover_repos_path:
        repos['snoop2']['local'] = os.path.abspath(config.hoover_repos_path)
        repos['search']['local'] = os.path.abspath(config.hoover_repos_path)
    if config.liquidinvestigations_repos_path:
        repos['core']['local'] = os.path.abspath(config.liquidinvestigations_repos_path)

    for repo, repo_config in repos.items():
        repo_path = os.path.join(repo_config['local'], repo)

        repo_volume_line = (f"\"{repo_path}:{repo_config['target']}\",\n")
        key = f"{repo_config['org']}_{repo}_repo"

        if config.mount_local_repos:
            substitutions[key] = repo_volume_line
        else:
            substitutions[key] = ''

    return substitutions


def get_collection_job(name, settings):
    """Return the collection job description

    :param name: collection name
    :param settings: dictionary containing the collection job options
    :returns: collection job description
    :rtype: str
    """

    substitutions = dict(settings)
    set_collection_defaults(name, substitutions)

    return get_job(config.templates / 'collection.nomad', substitutions)


def get_job(hcl_path, substitutions={}):
    """Return the job description generated from the given template

    :param hcl_path: the path to the hcl template file
    :param substitutions: dictionary containing the job options
    :returns: the job description
    :rtype: str
    """

    with hcl_path.open() as job_file:
        template = Template(job_file.read())

    return template.safe_substitute(set_volumes_paths(substitutions))
