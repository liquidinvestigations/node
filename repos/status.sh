#!/bin/bash
set -e

cd "$( dirname "${BASH_SOURCE[0]}" )"

for repo in hoover/snoop2 hoover/search hoover/ui liquidinvestigations/core liquidinvestigations/authproxy hypothesis/h; do (
  echo
    echo "[[ $repo ]]"
  if [ -d $repo ]; then
    cd $repo
    git status
  else
    echo "missing"
  fi
)
done
