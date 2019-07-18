import logging
import os
import subprocess

subprocess.check_call('pip install pymongo', shell=True)

import pymongo

log = logging.getLogger(__name__)
log.setLevel(logging.DEBUG)


def initiate_mongodb_replicaset():
    mongo = pymongo.MongoClient(
        os.environ['MONGO_ADDRESS'],
        int(os.environ['MONGO_PORT']),
    )

    log.info("Initiating replicaset")

    mongo.admin.command("replSetInitiate", {
        '_id': 'rs01',
        'members': [{'_id': 0, 'host': 'localhost:27017'}],
    })

    log.info("Success!")


def main():
    log.info("Starting RocketChat Caboose")
    try:
        initiate_mongodb_replicaset()
    except pymongo.errors.OperationFailure as e:
        if 'already initialized' in e.details['errmsg']:
            log.info('Done: already initialized.')
            return
        raise

    log.info("Done.")


if __name__ == '__main__':
    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s %(levelname)s %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
    )

    main()
