#!/bin/bash
set -e

cd "$( dirname "${BASH_SOURCE[0]}" )"
. repos.sh

for repo in "${repos[@]}"; do (
  echo
  echo
  echo "[[ $repo ]]"
  echo "   ---------------------------------"
  if [ -d $repo ]; then
    cd $repo
    git fetch -a
    git status
  else
    echo "missing"
  fi
)
done
