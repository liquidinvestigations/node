from liquid_node import jobs


class Drone(jobs.Job):
    name = 'drone'
    app = 'ci'
    template = jobs.TEMPLATES / f'{name}.nomad'
    stage = 2
    vault_secret_keys = [
        'liquid/ci/vmck.django',
        'liquid/ci/vmck.postgres',
        'liquid/ci/drone.rpc.secret',
    ]

    def extra_secret_fn(self, vault, config, random_secret):
        vault.set('liquid/ci/drone.github', {
            'client_id': config.ci_github_client_id,
            'client_secret': config.ci_github_client_secret,
            'user_filter': config.ci_github_user_filter,
        })
        vault.set('liquid/ci/drone.docker', {
            'username': config.ci_docker_username,
            'password': config.ci_docker_password,
        })
        vault.ensure_secret('liquid/ci/drone.secret.2', lambda: {
            'secret_key': random_secret(128),
        })


class Deps(jobs.Job):
    name = 'drone-deps'
    app = 'ci'
    template = jobs.TEMPLATES / f'{name}.nomad'
    stage = 1


class DroneWorkers(jobs.Job):
    name = 'drone-workers'
    app = 'ci'
    template = jobs.TEMPLATES / f'{name}.nomad'
    stage = 3
