#!/bin/bash
set -ex

for repo in hoover/snoop2 hoover/search liquidinvestigations/core; do
    echo $repo
    mkdir -p $repo
    if [ $1 -eq 'ssh' ]; then
            git clone "https://github.com/$repo.git" $repo
    elif [ $1 -eq 'https' ]; then
            git clone "git@github.com:$repo.git" $repo
    else
            set +x
            echo "Usage: $0 https - clone repos with https"
            echo "       $0 ssh   - clone repos with ssh"
            exit 1
    fi
done
