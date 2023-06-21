#!/bin/bash
set -ex

cd "$(dirname ${BASH_SOURCE[0]})/.."

./liquid shell wikijs:wikijs \
    bash -c 'PGPASSWORD=$DB_PASS pg_dumpall --no-password --dbname "$WIKIJS_DB" --database "$DB_NAME" --no-owner --inserts --column-inserts --no-acl' \
    > ./templates/wikijs-db-init-orig-dump.sql
