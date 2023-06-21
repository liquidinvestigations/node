#!/bin/bash
set -ex

echo "CONFIGURING MONGODB FOR $MONGO_ADDRESS:$MONGO_PORT"

mongo --host "$MONGO_ADDRESS" --port "$MONGO_PORT" <<EOFX
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

// rs.reconfig: https://dba.stackexchange.com/a/299546
new_config = rs.conf();
new_config["members"][0]["host"] = "localhost:27017";
rs.reconfig(new_config, {force:true});

rs.status();
EOFX
