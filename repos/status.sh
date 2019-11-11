#!/bin/bash
set -e

cd "$( dirname "${BASH_SOURCE[0]}" )"
. repos.sh

for repo in "${repos[@]}"; do (
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
