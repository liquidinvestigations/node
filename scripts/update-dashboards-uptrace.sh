#!/bin/bash -ex

cd "$(dirname ${BASH_SOURCE[0]})/.."

DOCKER_ID=$(docker ps | grep uptrace | cut -d' ' -f1)
if [[ -z "$DOCKER_ID" ]]; then
    echo "NO UPTRACE CONTAINER FOUND"
    exit 1
fi

(
    echo "BEGIN TRANSACTION;"
    echo "DELETE FROM dash_entries;"
    echo "DELETE FROM dashboards;"
    echo "DELETE FROM dash_gauges;"

    docker exec $DOCKER_ID sqlite3 /var/lib/uptrace/uptrace.sqlite3 ".dump" | \
        grep -E "INSERT INTO (dashboards|dash_entries|dash_gauges)"

    echo "COMMIT;"
) > ./uptrace-dashboards/dashboards.sql
