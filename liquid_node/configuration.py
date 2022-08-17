import sys
import re
import logging
import configparser
import os
import subprocess
import time
from distutils.util import strtobool
from pathlib import Path

from .util import import_string
from .docker import docker
from liquid_node.jobs import Job, liquid, hoover, dokuwiki, rocketchat, \
    nextcloud, codimd, ci


log = logging.getLogger(__name__)


def split_lang_codes(option):
    option = option.strip()
    if not option:
        return []
    return option.split(',')


class Configuration:
    ALL_APPS = ('hoover', 'dokuwiki', 'rocketchat', 'nextcloud',
                'codimd',)
    # The core apps can't be turned off.
    CORE_APPS = ('liquid', 'ingress',)

    APP_TITLE = {
        'dokuwiki': 'DokuWiki',
        'rocketchat': "Rocket.Chat",
        'codimd': "CodiMD",
    }

    APP_DESCRIPTION = {
        'hoover': 'is a search app.',
        'dokuwiki': 'is a wiki system used as a knowledge base for processed information.',
        'codimd': 'is a real-time collaboration pad.',
        'nextcloud': 'has a file share system and a contact list of users.',
        'rocketchat': 'is the chat app.'
    }

    ALL_JOBS = [
        liquid.SystemDeps(),
        liquid.Monitoring(),
        liquid.Liquid(),
        liquid.Ingress(),
        liquid.CreateUser(),
        liquid.DeleteUser(),
        liquid.AuthproxyRedis(),
        hoover.Hoover(),
        hoover.DepsDownloads(),
        hoover.Deps(),
        hoover.Proxy(),
        hoover.Nginx(),
        hoover.Workers(),
        dokuwiki.Dokuwiki(),
        dokuwiki.Proxy(),
        rocketchat.Rocketchat(),
        rocketchat.Deps(),
        rocketchat.Migrate(),
        nextcloud.Nextcloud(),
        nextcloud.Deps(),
        nextcloud.Migrate(),
        nextcloud.Periodic(),
        nextcloud.Proxy(),
        codimd.Codimd(),
        codimd.Deps(),
        codimd.Proxy(),
        ci.Drone(),
        ci.Deps(),
        ci.DroneWorkers(),
    ]

    def __init__(self):
        self.root = Path(__file__).parent.parent.resolve()
        self.templates = self.root / 'templates'

        self.ini = configparser.ConfigParser()
        self.ini.read(self.root / 'liquid.ini')

        self.versions_ini = configparser.ConfigParser()
        if (self.root / 'versions.ini').is_file():
            self.versions_ini.read(self.root / 'versions.ini')

        self.version_track = self.ini.get('liquid', 'version_track', fallback='production')
        self.track_ini = configparser.ConfigParser()
        assert (self.root / (self.version_track + '-versions.ini')).is_file(), \
            'invalid version_track'
        self.track_ini.read(self.root / (self.version_track + '-versions.ini'))

        self.cluster_root_path = self.ini.get('cluster', 'cluster_path', fallback=None)
        self.consul_url = self.ini.get('cluster', 'consul_url', fallback='http://127.0.0.1:8500')

        self.vault_url = self.ini.get('cluster', 'vault_url', fallback='http://127.0.0.1:8200')

        self.vault_token = None

        vault_secrets_path = self.ini.get('cluster', 'vault_secrets', fallback=None)
        if vault_secrets_path:
            secrets = configparser.ConfigParser()
            secrets.read(self.root / vault_secrets_path)
            self.vault_token = secrets.get('vault', 'root_token', fallback=None)

        self.nomad_url = self.ini.get('cluster', 'nomad_url', fallback='http://127.0.0.1:4646')

        self.liquid_domain = self.ini.get('liquid', 'domain', fallback='localhost')

        default_title = ' '.join(map(str.capitalize, self.liquid_domain.split('.')))
        self.liquid_title = self.ini.get('liquid', 'title', fallback=default_title)

        self.liquid_debug = self.ini.getboolean('liquid', 'debug', fallback=False)

        self.mount_local_repos = self.ini.getboolean('liquid', 'mount_local_repos', fallback=False)

        hoover_repos_path = self.ini.get('liquid', 'hoover_repos_path',
                                         fallback=str((self.root / 'repos' / 'hoover')))
        self.hoover_repos_path = str(Path(hoover_repos_path).resolve())

        li_repos_path = self.ini.get('liquid', 'liquidinvestigations_repos_path',
                                     fallback=str((self.root / 'repos' / 'liquidinvestigations')))
        self.liquidinvestigations_repos_path = str(Path(li_repos_path).resolve())

        self.liquid_volumes = self.ini.get('liquid', 'volumes', fallback=None)

        self.liquid_collections = self.ini.get('liquid', 'collections',
                                               fallback=str(self.root / 'collections'))

        self.liquid_http_port = self.ini.get('liquid', 'http_port', fallback='80')

        self.https_enabled = 'https' in self.ini
        if self.https_enabled:
            self.liquid_http_protocol = 'https'
            self.liquid_https_port = self.ini.get('https', 'https_port', fallback='443')
            self.https_acme_email = self.ini.get('https', 'acme_email')
            self.https_acme_caServer = self.ini.get(
                'https',
                'acme_caServer',
                fallback="https://acme-staging-v02.api.letsencrypt.org/directory"
            )

        else:
            self.liquid_http_protocol = self.ini.get('liquid', 'http_protocol_override', fallback='http')
        self.liquid_core_url = f'{self.liquid_http_protocol}://{self.liquid_domain}'

        self.auth_staff_only = self.ini.getboolean('liquid', 'auth_staff_only', fallback=False)

        self.auth_auto_logout = self.ini.get('liquid', 'auth_auto_logout', fallback='2400h')

        self.liquid_2fa = self.ini.getboolean('liquid', 'two_factor_auth', fallback=False)

        self.elasticsearch_heap_size = self.ini.getint('liquid', 'elasticsearch_heap_size',
                                                       fallback=2000)
        self.elasticsearch_memory_limit = self.ini.getint('liquid', 'elasticsearch_memory_limit',
                                                          fallback=4000)
        self.elasticsearch_data_node_count = self.ini.getint('liquid', 'elasticsearch_data_node_count', fallback=0)  # noqa: E501

        self.tika_count = self.ini.getint('liquid', 'tika_count', fallback=1)
        self.tika_memory_limit = self.ini.getint('liquid', 'tika_memory_limit', fallback=2500)

        self.nextcloud_memory_limit = \
            self.ini.getint('liquid',
                            'nextcloud_memory_limit',
                            fallback=512)

        self.hoover_ratelimit_user = self.ini.get('liquid', 'hoover_ratelimit_user', fallback='100,13')

        self.hoover_web_memory_limit = self.ini.getint('liquid',
                                                       'hoover_web_memory_limit', fallback=400)
        self.hoover_web_count = self.ini.getint('liquid',
                                                'hoover_web_count', fallback=1)
        self.rocketchat_show_login_form = self.ini.getboolean('liquid', 'rocketchat_show_login_form', fallback=True)  # noqa: E501
        self.rocketchat_enable_push = self.ini.getboolean('liquid', 'rocketchat_enable_push', fallback=False)  # noqa: E501
        self.rocketchat_autologout_days = self.ini.getint('liquid', 'rocketchat_autologout_days', fallback=100)  # noqa: E501

        self.hoover_ui_override_server = self.ini.get('liquid', 'hoover_ui_override_server', fallback='')
        self.hoover_es_max_concurrent_shard_requests = self.ini.getint(
            'liquid', 'hoover_es_max_concurrent_shard_requests', fallback=''
        )
        self.hoover_ui_force_pull = self.ini.getboolean('liquid', 'hoover_ui_force_pull', fallback=False)
        self.hoover_ui_agg_split = self.ini.getint('liquid', 'hoover_ui_agg_split', fallback=1)
        self.hoover_ui_search_retry = self.ini.getint('liquid', 'hoover_ui_search_retry', fallback=1)

        self.hoover_ui_search_retry_delay = self.ini.getint('liquid', 'hoover_ui_search_retry_delay',
                                                            fallback=3000)
        self.hoover_ui_async_search_poll_interval = (
            self.ini.getint('liquid',
                            'hoover_ui_async_search_poll_interval',
                            fallback=45))
        self.hoover_ui_async_search_max_final_retries = (
            self.ini.getint('liquid',
                            'hoover_ui_async_search_max_final_retries',
                            fallback=3))
        self.hoover_ui_async_search_error_multiplier = (
            self.ini.getint('liquid',
                            'hoover_ui_async_search_error_multiplier',
                            fallback=2))
        self.hoover_ui_async_search_error_summation = (
            self.ini.getint('liquid',
                            'hoover_ui_async_search_error_summation',
                            fallback=60))

        self.hoover_maps_enabled = self.ini.getboolean('liquid', 'hoover_maps_enabled', fallback=False)

        self.hoover_search_debug_delay = self.ini.getint('liquid', 'hoover_search_debug_delay', fallback=0)

        self.snoop_workers_enabled = self.ini.getboolean('snoop', 'enable_workers', fallback=True)
        if (self.ini.get('snoop', 'min_workers_per_node', fallback='')
                or self.ini.get('snoop', 'max_workers_per_node', fallback='')
                or self.ini.get('snoop', 'worker_cpu_count_multiplier', fallback='')):
            log.error('These settings have been removed, but they are still present: ')
            log.error('"min_workers_per_node", "max_workers_per_node", "worker_cpu_count_multiplier".')
            log.error('Please remove them from your configuration.')
            sys.exit(1)
        self.snoop_container_process_count = self.ini.getint('snoop',
                                                             'container_process_count', fallback=1)  # noqa: E501
        assert 1 <= self.snoop_container_process_count <= 8, 'invalid process container count: not in [1, 8]'

        self.snoop_default_queue_worker_count = self.ini.getint('snoop', 'default_queue_worker_count', fallback=1)  # noqa: E501
        self.snoop_filesystem_queue_worker_count = self.ini.getint('snoop', 'filesystem_queue_worker_count', fallback=1)  # noqa: E501
        self.snoop_ocr_queue_worker_count = self.ini.getint('snoop', 'ocr_queue_worker_count', fallback=1)  # noqa: E501
        self.snoop_digests_queue_worker_count = self.ini.getint('snoop', 'digests_queue_worker_count', fallback=1)  # noqa: E501

        self.snoop_rabbitmq_memory_limit = self.ini.getint('snoop', 'rabbitmq_memory_limit', fallback=1500)
        self.snoop_postgres_memory_limit = self.ini.getint('snoop', 'postgres_memory_limit', fallback=2100)
        self.snoop_postgres_max_connections = self.ini.getint('snoop', 'postgres_max_connections', fallback=350)  # noqa: E501
        self.snoop_postgres_pool_children = int(self.snoop_postgres_max_connections / 2 - 3)

        self.snoop_max_result_window = self.ini.getint('snoop', 'max_result_window', fallback=10000)
        self.snoop_refresh_interval = self.ini.get('snoop', 'refresh_interval', fallback="1s")

        self.snoop_pdf_preview_enabled = self.ini.getboolean('snoop', 'pdf_preview_enabled', fallback=False)
        self.snoop_pdf_preview_count = self.ini.getint('snoop', 'pdf_preview_count', fallback=1)
        self.snoop_pdf_preview_memory_limit = self.ini.getint('snoop', 'pdf_preview_memory_limit',
                                                              fallback=950)
        self.snoop_thumbnail_generator_enabled = self.ini.getboolean('snoop', 'thumbnail_generator_enabled',
                                                                     fallback=False)
        self.snoop_thumbnail_generator_count = self.ini.getint('snoop', 'thumbnail_generator_count',
                                                               fallback=1)
        self.snoop_thumbnail_generator_memory_limit = self.ini.getint('snoop',
                                                                      'thumbnail_generator_memory_limit',
                                                                      fallback=850)

        self.snoop_image_classification_count = self.ini.getint('snoop', 'image_classification_count',
                                                                fallback=1)
        self.snoop_image_classification_memory_limit = self.ini.getint('snoop',
                                                                       'image_classification_memory_limit',
                                                                       fallback=1150)

        self.snoop_image_classification_object_detection_enabled = \
            self.ini.getboolean('snoop', 'image_classification_object_detection_enabled', fallback=False)
        self.snoop_image_classification_object_detection_model = \
            self.ini.get('snoop', 'image_classification_object_detection_model', fallback='yolo')

        self.snoop_image_classification_classify_images_enabled = \
            self.ini.getboolean('snoop', 'image_classification_classify_images_enabled', fallback=False)
        self.snoop_image_classification_classify_images_model = \
            self.ini.get('snoop', 'image_classification_classify_images_model', fallback='mobilenet')

        self.snoop_nlp_fallback_language = self.ini.get('snoop', 'nlp_fallback_language', fallback="en")
        self.snoop_nlp_spacy_text_limit = self.ini.get('snoop', 'nlp_spacy_text_limit', fallback=40000)
        self.snoop_nlp_memory_limit = self.ini.getint('snoop', 'nlp_memory_limit', fallback=950)
        self.snoop_nlp_count = self.ini.getint('snoop', 'nlp_count', fallback=1)
        self.snoop_nlp_entity_extraction_enabled =  \
            self.ini.getboolean('snoop', 'nlp_entity_extraction_enabled', fallback=False)
        self.snoop_nlp_language_detection_enabled = \
            self.ini.getboolean('snoop', 'nlp_language_detection_enabled', fallback=False)
        self.snoop_nlp_text_length_limit = \
            self.ini.getint('snoop', 'nlp_text_length_limit', fallback=1000000)

        self.snoop_translation_enabled = \
            self.ini.getboolean('snoop', 'translation_enabled', fallback=False)
        self.snoop_translation_count = \
            self.ini.getint('snoop', 'translation_count', fallback=1)
        self.snoop_translation_memory_limit = \
            self.ini.getint('snoop', 'translation_memory_limit', fallback=850)
        self.snoop_translation_target_languages = \
            self.ini.get('snoop', 'translation_target_languages', fallback="en")
        self.snoop_translation_text_length_limit = \
            self.ini.getint('snoop', 'translation_text_length_limit', fallback=400)

        self.snoop_skip_mime_types = \
            self.ini.get('snoop', 'skip_mime_types', fallback='application/octet-stream,application/x-dosexec,text/xml,application/x-setupscript,text/x-c,font/sfnt,image/x-win-bitmap,application/x-pnf,image/vnd.microsoft.icon,application/x-wine-extension-ini,application/x-empty,application/x-object,application/x-sharedlib,text/x-bytecode.python,text/x-shellscript,text/x-script.python,image/svg+xml,amd64.md5sums,amd64.list,amd64.triggers,amd64.shlibs,amd64.symbols,application/x-pie-executable,application/vnd.debian.binary-package,text/x-asm')  # noqa: E501
        self.snoop_skip_extensions = \
            self.ini.get('snoop', 'skip_extensions', fallback='.3gr,.acm,.adml,.admx,.aspx,.aux,.ax,.bin,.cat,.cdf-ms,.cdxml,.com,.config,.cpl,.css,.cur,.dat,.dll,.dll,.drv,.etl,.exe,.fon,.fot,.ico,.ime,.inf,.inf_loc,.ini,.js,.lnk,.man,.manifest,.mfl,.mof,.msc,.msi,.mui,.mum,.mun,.nls,.ocx,.pnf,.pnf,.pri,.ps1,.ps1xml,.psd1,.psm1,.resx,.scr,.sys,.tlb,.tte,.ttf,.vbx,.winmd,.xbf,.xml,.xrm-ms,.xsd')  # noqa: E501
        self.snoop_worker_omp_thread_limit = self.ini.getint('snoop', 'snoop_worker_omp_thread_limit',
                                                             fallback=2)
        self.snoop_ocr_parallel_pages = self.ini.getint('snoop', 'snoop_ocr_parallel_pages', fallback=2)

        self.check_interval = self.ini.get('deploy', 'check_interval', fallback='30s')
        self.check_timeout = self.ini.get('deploy', 'check_timeout', fallback='29s')
        self.wait_max = self.ini.getfloat('deploy', 'wait_max_sec', fallback=600)
        self.wait_interval = self.ini.getfloat('deploy', 'wait_interval', fallback=10)
        self.wait_green_count = self.ini.getint('deploy', 'wait_green_count', fallback=4)

        self.container_memory_limit_scale = self.ini.getfloat(
            'deploy', 'container_memory_limit_scale', fallback=1.0)
        assert 0.7 <= self.container_memory_limit_scale <= 5.0, 'invalid value'
        self.container_cpu_scale = self.ini.getfloat('deploy', 'container_cpu_scale', fallback=1.0)
        assert 0.2 <= self.container_cpu_scale <= 5.0, 'invalid value'
        # scale heap size separately because it's not reached by the nomad MemoryMB edit function
        self.elasticsearch_heap_size = int(self.elasticsearch_heap_size * self.container_memory_limit_scale)

        self.ci_enabled = 'ci' in self.ini
        if self.ci_enabled:
            self.ci_runner_capacity = self.ini.getint('ci', 'runner_capacity', fallback=4)
            self.ci_docker_username = self.ini.get('ci', 'docker_username')
            self.ci_docker_password = self.ini.get('ci', 'docker_password')
            self.ci_github_client_id = self.ini.get('ci', 'github_client_id')
            self.ci_github_client_secret = self.ini.get('ci', 'github_client_secret')
            self.ci_github_user_filter = self.ini.get('ci', 'github_user_filter')

            self.ci_target_hostname = self.ini.get('ci', 'target_hostname')
            self.ci_target_username = self.ini.get('ci', 'target_username')
            self.ci_target_password = self.ini.get('ci', 'target_password')
            self.ci_target_port = self.ini.get('ci', 'target_port')
            self.ci_target_test_admin_password = self.ini.get('ci', 'target_test_admin_password')

        self.default_app_status = self.ini.get('apps', 'default_app_status', fallback='on')
        self.all_jobs = list(self.ALL_JOBS)
        self.enabled_jobs = [job for job in self.all_jobs if self.is_app_enabled(job.app)]
        self.disabled_jobs = [job for job in self.all_jobs if not self.is_app_enabled(job.app)]

        self.image_keys = set(self.track_ini['versions']) | \
            (set(self.versions_ini['versions']) if 'versions' in self.versions_ini.sections() else set()) | \
            (set(self.ini['versions']) if 'versions' in self.ini.sections() else set())
        self.images = set(self._image(c) for c in self.image_keys)

        self.PORT_MAP = {
            'lb': self.ini.getint('ports', 'lb', fallback=9990),
            'blobs_minio': self.ini.getint('ports', 'blobs_minio', fallback=9991),
            'collections_minio': self.ini.getint('ports', 'collections_minio', fallback=9992),
            'authproxy_redis': self.ini.getint('ports', 'authproxy_redis', fallback=9993),
            'drone_ci': self.ini.getint('ports', 'drone_ci', fallback=9997),
            'snoop_pg': self.ini.getint('ports', 'snoop_pg', fallback=9981),
            'snoop_pg_pool': self.ini.getint('ports', 'snoop_pg_pool', fallback=9982),
            'search_pg': self.ini.getint('ports', 'search_pg', fallback=9983),
            'snoop_rabbitmq': self.ini.getint('ports', 'snoop_rabbitmq', fallback=9984),
            'search_rabbitmq': self.ini.getint('ports', 'search_rabbitmq', fallback=9985),
            'rocketchat_mongo': self.ini.getint('ports', 'rocketchat_mongo', fallback=9986),
            'nextcloud_maria': self.ini.getint('ports', 'nextcloud_maria', fallback=9987),
            'codimd_pg': self.ini.getint('ports', 'codimd_pg', fallback=9988),
            'codimd': self.ini.getint('ports', 'codimd', fallback=9989),
            'nextcloud': self.ini.getint('ports', 'nextcloud', fallback=9996),
            'hoover': self.ini.getint('ports', 'hoover', fallback=9994),
            'dokuwiki': self.ini.getint('ports', 'dokuwiki', fallback=9995),
            'rocketchat': self.ini.getint('ports', 'rocketchat', fallback=9980),
            'hoover_es_master_transport': self.ini.getint('ports',
                                                          'hoover_es_master_transport',
                                                          fallback=9979),
            'zipkin': self.ini.getint('ports', 'zipkin', fallback=9978),
        }

        self.port_lb = self.PORT_MAP['lb']
        self.port_blobs_minio = self.PORT_MAP['blobs_minio']
        self.port_collections_minio = self.PORT_MAP['collections_minio']
        self.port_authproxy_redis = self.PORT_MAP['authproxy_redis']
        self.port_drone_ci = self.PORT_MAP['drone_ci']
        self.port_snoop_pg = self.PORT_MAP['snoop_pg']
        self.port_snoop_pg_pool = self.PORT_MAP['snoop_pg_pool']
        self.port_search_pg = self.PORT_MAP['search_pg']
        self.port_snoop_rabbitmq = self.PORT_MAP['snoop_rabbitmq']
        self.port_search_rabbitmq = self.PORT_MAP['search_rabbitmq']
        self.port_rocketchat_mongo = self.PORT_MAP['rocketchat_mongo']
        self.port_nextcloud_maria = self.PORT_MAP['nextcloud_maria']
        self.port_codimd_pg = self.PORT_MAP['codimd_pg']
        self.port_codimd = self.PORT_MAP['codimd']
        self.port_nextcloud = self.PORT_MAP['nextcloud']
        self.port_hoover = self.PORT_MAP['hoover']
        self.port_dokuwiki = self.PORT_MAP['dokuwiki']
        self.port_rocketchat = self.PORT_MAP['rocketchat']
        self.port_hoover_es_master_transport = self.PORT_MAP['hoover_es_master_transport']
        self.port_zipkin = self.PORT_MAP['zipkin']

        self.snoop_collections = []

        # load collections and extra jobs
        for key in self.ini:
            if ':' not in key:
                continue

            (cls, name) = key.split(':')

            if cls == 'collection':
                Configuration._validate_collection_name(name)
                if not self.ini.getboolean(key, 'disable_archive_mounting', fallback=True):
                    log.warning('Collection %s: Enabling archive mounting may cause processing errors.', name)
                    log.warning('Collection %s: Please consider removing the configuration line:', name)
                    log.warning('Collection %s: `disable_archive_mounting=False`.\n', name)

                self.snoop_collections.append({
                    'name': name,
                    'process': self.ini.getboolean(key, 'process', fallback=False),
                    'sync': self.ini.getboolean(key, 'sync', fallback=False),
                    'ocr_languages': split_lang_codes(self.ini.get(key, 'ocr_languages', fallback='')),
                    'max_result_window': self.ini.getint(
                        key,
                        'max_result_window',
                        fallback=self.snoop_max_result_window,
                    ),
                    'refresh_interval': self.ini.getint(
                        key,
                        'refresh_interval',
                        fallback=self.snoop_refresh_interval,
                    ),
                    'pdf_preview_enabled': self.ini.getboolean(
                        key,
                        'pdf_preview_enabled',
                        fallback=self.snoop_pdf_preview_enabled,
                    ),
                    'thumbnail_generator_enabled': self.ini.getboolean(
                        key,
                        'thumbnail_generator_enabled',
                        fallback=self.snoop_thumbnail_generator_enabled,
                    ),
                    'image_classification_object_detection_enabled': self.ini.getboolean(
                        key,
                        'image_classification_object_detection_enabled',
                        fallback=self.snoop_image_classification_object_detection_enabled,
                    ),
                    'image_classification_classify_images_enabled': self.ini.getboolean(
                        key,
                        'image_classification_classify_images_enabled',
                        fallback=self.snoop_image_classification_classify_images_enabled,
                    ),
                    'nlp_language_detection_enabled': self.ini.getboolean(
                        key,
                        'nlp_language_detection_enabled',
                        fallback=self.snoop_nlp_language_detection_enabled,
                    ),
                    'nlp_entity_extraction_enabled': self.ini.getboolean(
                        key,
                        'nlp_entity_extraction_enabled',
                        fallback=self.snoop_nlp_entity_extraction_enabled,
                    ),
                    'translation_enabled': self.ini.getboolean(
                        key,
                        'translation_enabled',
                        fallback=self.snoop_translation_enabled,
                    ),
                    'translation_target_languages': self.ini.get(
                        key,
                        'translation_target_languages',
                        fallback=self.snoop_translation_target_languages,
                    ),
                    'translation_text_length_limit': self.ini.get(
                        key,
                        'translation_text_length_limit',
                        fallback=self.snoop_translation_text_length_limit,
                    ),
                    'default_table_header': self.ini.get(
                        key,
                        'default_table_header',
                        fallback='',
                    ),
                    'explode_table_rows': self.ini.getboolean(
                        key,
                        'explode_table_rows',
                        fallback=False,
                    ),
                    'disable_archive_mounting': self.ini.getboolean(
                        key,
                        'disable_archive_mounting',
                        fallback=True,
                    ),
                })

            elif cls == 'job':
                self.enabled_jobs.append(self.load_job(name, self.ini[key]))

        self.timestamp = int(time.time())

        self.liquid_apps = []
        for app in self.ALL_APPS:
            self.liquid_apps.append({
                'id': app,
                'title': self.APP_TITLE.get(app) or app.title(),
                'url': self.app_url(app),
                'enabled': self.is_app_enabled(app),
                'description': self.APP_DESCRIPTION[app],
                'adminOnly': False,
                'version': self.version(app),
            })
        self.liquid_version = self.get_node_version()
        self.liquid_core_version = self.version('liquid-core')

        self.liquid_apps.append({
            'id': "nextcloud-admin",
            'title': "Nextcloud Admin",
            'url': self.app_url('nextcloud') + "/index.php/login?autologin=admin",
            'enabled': self.is_app_enabled('nextcloud'),
            'description': "will log you in as the Nextcloud admin user. "
            "You may need to log out of Nextcloud first.",
            'adminOnly': True,
            'version': '',
        })

    def get_node_version(self):
        try:
            return subprocess.check_output(['git', 'describe', '--tags'], shell=False).decode().strip()
        except subprocess.CalledProcessError:
            return os.getenv('LIQUID_VERSION', 'unknown version')

    def version(self, name):
        def tag(name):
            return self._image(name).split(':', 1)[1]

        if name == 'hoover':
            search = tag('hoover-search')
            snoop = tag('hoover-snoop2')
            ui = tag('hoover-ui')
            return f'search: {search},  snoop: {snoop}, ui: {ui}'

        if name in ['dokuwiki', 'nextcloud']:
            return tag('liquid-' + name)

        return tag(name)

    def _image(self, name):
        """Returns the NAME:TAG for a docker image from versions.ini.

        Can be overrided in liquid.ini, same section name.
        """

        for x in [self.ini, self.versions_ini, self.track_ini]:
            val = x.get('versions', name, fallback=None)
            if val:
                return val.strip()
        else:
            raise RuntimeError('image does not exist: ' + name)

    def image(self, name):
        """Returns the NAME@SHA1 for a docker image from the docker system."""
        return docker.image_digest(self._image(name))

    def load_job(self, name, job_config):
        if 'template' in job_config:
            job = Job()
            job.name = name
            job.template = self.root / job_config['template']
            return job

        if 'loader' in job_config:
            job_loader = import_string(job_config['loader'])
            return job_loader(name, job_config, self)

        raise RuntimeError("A job needs `template` or `loader`")

    def app_url(self, name):
        return f'{self.liquid_http_protocol}://{name}.{self.liquid_domain}'

    def is_app_enabled(self, app_name):
        if app_name == 'ci':
            return self.ci_enabled
        return app_name in Configuration.CORE_APPS or \
            self.ini.getboolean('apps', app_name, fallback=strtobool(self.default_app_status))

    def ports_proxy_addr(self):
        res = ''
        for port in self.PORT_MAP.items():
            if port[0] != 'lb':
                res += f':{port[1]};proto=tcp,'
            else:
                res += f':{port[1]};proto=http,'
        return res

    def ports_resources_network(self):
        res = ''
        for port in self.PORT_MAP.items():
            res += f'port "{port[0]}" {{ static =  {port[1]} }}\n'
        return res

    def port_map(self):
        res = ''
        for port in self.PORT_MAP.items():
            res += f'{port[0]} = {port[1]}\n'
        return res

    @classmethod
    def _validate_collection_name(cls, name):

        # collection names are restricted by minio (s3) and elasticsearch
        # for reference see:
        # https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-create-index.html#indices-create-api-path-params
        # https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html

        # TODO Uppercase is not allowed by s3 so no new buckets with uppercase can and should not be created.
        # But Minio accepts uppercase letters if the directories on disk exist already.
        # We don't have a logic to solve this problem and handle these cases right now.
        # We just allow uppercase to keep the existing collections working.

        search_forbidden_char = re.compile(r'[^a-zA-Z0-9-]').search

        if search_forbidden_char(name) or not name[0].islower():
            raise ValueError(f'''Invalid collection name "{name}"!

                Collection names must start with lower case letters and must contain only
                lower case letters, digits or hyphens ('-').
                ''')
        if len(name) < 3 or len(name) > 63:
            raise ValueError(f'''Invalid collection name "{name}"!

            Collection name must be between 3 and 63 characters long
            (Minio / S3 bucket name restriction).''')

    @property
    def total_snoop_worker_count(self):
        """Get total number of CPU cores to run in Snoop."""
        if not config.snoop_workers_enabled:
            return 0

        container_count = 0
        container_count += self.snoop_default_queue_worker_count
        container_count += self.snoop_filesystem_queue_worker_count
        container_count += self.snoop_ocr_queue_worker_count
        container_count += self.snoop_digests_queue_worker_count

        if self.snoop_pdf_preview_enabled:
            container_count += self.snoop_pdf_preview_count

        if self.snoop_thumbnail_generator_enabled:
            container_count += self.snoop_thumbnail_generator_count

        if self.snoop_image_classification_object_detection_enabled \
                or self.snoop_image_classification_classify_images_enabled:
            container_count += self.snoop_image_classification_count

        if self.snoop_nlp_entity_extraction_enabled:
            container_count += self.snoop_nlp_count

        if self.snoop_translation_enabled:
            container_count += self.snoop_translation_count

        return self.snoop_container_process_count * container_count

    def get_dashboards(self):
        return list(os.listdir(self.root / 'grafana-dashboards'))

    def load_dashboard(self, filename):
        with open(self.root / 'grafana-dashboards' / filename) as f:
            return f.read()


config = Configuration()
