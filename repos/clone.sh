#!/bin/bash
set -e

cd "$( dirname "${BASH_SOURCE[0]}" )"

for repo in hoover/snoop2 hoover/search hoover/ui liquidinvestigations/core liquidinvestigations/authproxy hypothesis/h; do (
    echo
    echo "[[ $repo ]]"
    if [ -d $repo ]; then (
      cd $repo
      git fetch -q
      set -x
      git status
      git pull -q --ff-only || echo "pull failed :("
    ); else (
      set -x
      mkdir -p $repo
      if [ "$1" == 'ssh' ]; then
              git clone "git@github.com:$repo.git" $repo
      elif [ "$1" == 'https' ]; then
              git clone "https://github.com/$repo.git" $repo
      else
              set +x
              echo "Usage: $0 https - clone repos with https"
              echo "       $0 ssh   - clone repos with ssh"
              exit 1
      fi
    );
    fi
); done
