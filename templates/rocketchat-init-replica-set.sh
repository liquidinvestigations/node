#!/bin/bash -ex

mongo --host $MONGO_ADDRESS --port $MONGO_PORT <<EOF
var config = {
    "_id": "rs01",
    "version": 1,
    "members": [
        {
            "_id": 0,
            "$MONGO_ADDRESS:$MONGO_PORT",
            "priority": 3
        }
    ]
};
rs.initiate(config, { force: true });
"rs.secondaryOk()" >> ~/.mongorc.js
rs.status();
EOF
