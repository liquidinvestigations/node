#!/bin/bash -ex

mongo --host $MONGO_ADDRESS --port $MONGO_PORT <<EOF
var config = {
    "_id": "rs01",
    "version": 1,
    "members": [
        {
            "_id": 0,
            "host": "localhost:27017",
            "priority": 3
        }
    ]
};
rs.initiate(config, { force: true });
rs.status();
EOF