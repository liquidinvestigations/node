import logging
import os
import time

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
    except:  # noqa: E722
        log.exception("Failed `initiate_mongodb_replicaset`")

    log.info("Done. sleeping forever.")
    try:
        while True:
            time.sleep(100)
    finally:
        log.info("Exiting RocketChat Caboose? Sadness :(")


if __name__ == '__main__':
    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s %(levelname)s %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
    )

    main()
