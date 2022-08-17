import multiprocessing
import random
import time
import json
import logging

import matplotlib.pyplot as plt
import matplotlib.ticker as ticker

from .jsonapi import JsonApi
from .nomad import nomad
from .configuration import config


log = logging.getLogger(__name__)


ALL_WORDS = None
ALL_REQUESTS = None
ES_COLLECTION_SIZE = None
ES_COLLECTION_PROB = None
HTTP_PORT = config.port_lb


def _init_words():
    global ALL_WORDS, ALL_REQUESTS
    if ALL_WORDS is None:
        with open('.hoover-queries/words.txt', 'r') as f:
            ALL_WORDS = list(x.strip() for x in f.readlines())
        with open('.hoover-queries/queries.json.lines', 'r') as f:
            ALL_REQUESTS = list(f.readlines())
        log.debug('words loaded')


def _init_collection_stats():
    global ES_COLLECTION_SIZE, ES_COLLECTION_PROB

    def get_prob():
        EXPERIMENT_COUNT = 5000
        SAVE_REZ = 500

        c_list = list(ES_COLLECTION_SIZE.keys())
        exp = {}
        for _ in range(EXPERIMENT_COUNT):
            k = random.randint(1, len(c_list))
            c = tuple(random.choices(c_list, k=k))
            exp[c] = sum(ES_COLLECTION_SIZE[col] for col in c) / sum(ES_COLLECTION_SIZE.values())

        p = []
        for i in range(SAVE_REZ + 1):
            r = i / SAVE_REZ
            point = min(exp.keys(), key=lambda k: abs(exp[k] - r))
            p.append(point)

        return p

    if ES_COLLECTION_SIZE is None:
        es = JsonApi(f'http://{nomad.get_address()}:{HTTP_PORT}/_es')
        indices = es.get('/_stats/store')['indices']
        ES_COLLECTION_SIZE = {k: indices[k]['total']['store']['size_in_bytes']
                              for k in indices if not k.startswith('.')}
        ES_COLLECTION_PROB = get_prob()
        log.debug('collection stats loaded')


def get_collections():
    _init_collection_stats()
    r = list(random.choice(ES_COLLECTION_PROB))
    random.shuffle(r)
    return r


def get_query():
    return random.choice(ALL_WORDS) + " OR " + random.choice(ALL_WORDS)


def do_single_search(collections, word):
    es = JsonApi(f'http://{nomad.get_address()}:{HTTP_PORT}/_es')
    col_str = ",".join(collections)

    url = ('/'
           + col_str
           + "/_search"
           + '?ignore_unavailable=true'
           + '&allow_partial_search_results=false'
           + '&request_cache=false'
           + '&batched_reduce_size=30'
           + '&max_concurrent_shard_requests=10'
           + '&timeout=150s'
           + '&size=10')

    hits = 0
    for template in ALL_REQUESTS:
        body = template.replace('HOOVER_SEARCH_QUERY', word)

        try:
            res = es.get(url, data=json.loads(body))
        except Exception as e:
            log.exception(e)
            return False, 0
        if res['timed_out']:
            return False, 0
        hits += len(res['hits']['hits'])
    return True, hits / len(ALL_REQUESTS)


def do_sequential_searches(search_count):
    assert search_count > 0
    x1 = []
    y1 = []
    z1 = []

    MIN_HITS = 1
    ACTUAL_SEARCH_MULTIPLIER = 4
    MAX_ERRORS = int(ACTUAL_SEARCH_MULTIPLIER * (search_count + 1) / 2 + 3)

    _init_words()

    i = 0
    ii = 0
    errors = 0
    while i < search_count and ii < ACTUAL_SEARCH_MULTIPLIER * (search_count + 1):
        collections = get_collections()
        x = sum(ES_COLLECTION_SIZE[c] for c in collections)

        # do requests
        t0 = time.time()
        q = get_query()
        good, hits = do_single_search(collections, q)
        t1 = time.time()

        if not good:
            log.error('errored out on search "%s" on %s collections!', q, len(collections))
            errors += 1
            assert errors < MAX_ERRORS, "too many errors ({errors}), ES server dead!"
            time.sleep(0.1)
            continue

        y = (t1 - t0)

        x1.append(x)
        y1.append(y)
        z1.append(hits)

        if hits >= MIN_HITS:
            i += 1
        ii += 1
    log.debug('requested searches with results: %s, actual search count: %s', search_count, ii)
    return x1, y1, z1


def do_parallel_searches(c, search_count):
    BATCH_SPLIT = 2

    if search_count < c * BATCH_SPLIT:
        search_count = c * BATCH_SPLIT
    if c == 1:
        _init_collection_stats()
        _init_words()
        log.info('collection sizes: ' + str(ES_COLLECTION_SIZE))
    log.info('running %s searches in %s parallel processes', search_count, c)
    x1 = []
    y1 = []
    z1 = []
    with multiprocessing.Pool(c) as p:
        buckets = c * BATCH_SPLIT
        bucket_search_count = max(1, int(search_count / buckets))
        current_bucket = 0
        for x, y, z in p.imap_unordered(do_sequential_searches, [bucket_search_count] * buckets):
            x1 += x
            y1 += y
            z1 += z
            current_bucket += 1
            if current_bucket % int(buckets / BATCH_SPLIT) == 0:
                log.info("searches done: %s%%", int(100 * current_bucket / buckets))
    return x1, y1, z1


def plot(search_count, max_concurrent, path):
    UNITS = [(2**0, 'B'), (2**10, 'KB'), (2**20, 'MB'), (2**30, 'GB'), (2**40, 'TB')]

    concurrency = [1]
    EXPONENT = 3
    while concurrency[-1] < max_concurrent:
        concurrency.append(concurrency[-1] * EXPONENT)

    fig, tables = plt.subplots(len(concurrency), 1)
    fig.suptitle('Search time plot')

    for table, c in zip(tables, concurrency):
        try:
            t0 = time.time()
            x, y, z = do_parallel_searches(c, search_count + 6 * max_concurrent)
            dt = time.time() - t0
            speedup = sum(y) / dt
            average = sum(y) / len(y)
        except Exception as e:
            log.exception(e)
            log.error("STOPPING concurrency = %s because of error", c)
            # on low concurrency, quit here
            if c < 5:
                raise
            break

        xmax = max(x)
        for unit_val, unit_name in UNITS:
            if unit_val * 2**10 > xmax:
                break
        x = [xx / unit_val for xx in x]

        scatter = table.scatter(x, y, s=3, c=z, cmap='coolwarm')
        cb = plt.colorbar(scatter, ax=table)
        cb.set_label('hits')
        table.set_ylabel('search time')
        table.set_title(f'{c} concurrent searchers: {len(x)} searches in {dt:0.2f}s (average {average:0.2f}s/req, speedup {speedup:0.2f})')  # noqa: E501
        table.yaxis.set_major_formatter(ticker.FormatStrFormatter('%.2f s'))
        table.xaxis.set_major_formatter(ticker.FormatStrFormatter('%.1f ' + unit_name))
    table.set_xlabel('total searched collections size')
    fig.tight_layout()

    fig.set_size_inches(12, 12)
    fig.savefig(path, dpi=200)
    log.info('figure saved to %s', path)
