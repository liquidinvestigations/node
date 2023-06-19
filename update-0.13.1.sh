#!/bin/bash
set -ex

cd "$(dirname ${BASH_SOURCE[0]})"

./liquid dockerexec hoover:search ./manage.py dumpuuids | ./liquid dockerexec hoover:snoop ./manage.py importtagsuuids

echo "DONE"
