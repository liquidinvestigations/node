#!/bin/bash
set -e

cd "$( dirname "${BASH_SOURCE[0]}" )"

if [ "$1" == 'ssh' ]; then
        echo "using ssh"
elif [ "$1" == 'https' ]; then
        echo "using https"
else
        set +x
        echo "Usage: $0 https - clone repos with https"
        echo "       $0 ssh   - clone repos with ssh"
        exit 1
fi

repos=(
        liquidinvestigations/hoover-snoop2
        liquidinvestigations/hoover-search
        liquidinvestigations/hoover-ui
        liquidinvestigations/core
        liquidinvestigations/authproxy
        liquidinvestigations/hypothesis-h
        liquidinvestigations/codimd-server
)

logs=$(mktemp -d)
for repo in "${repos[@]}"; do
  mkdir -p $(dirname "$logs/$repo") || true
  touch $logs/$repo
  (
    echo
    echo "[[ $repo ]]"

    if [ -d $repo ]; then (
      cd $repo
      git fetch -q
      set -x
      git status
      git pull -q --ff-only || echo "pull for $repo failed :("
    ); else (
      set -x
      mkdir -p $( dirname $repo )
      if [ "$1" == 'ssh' ]; then
        git clone "git@github.com:$repo.git" $repo
      elif [ "$1" == 'https' ]; then
        git clone "https://github.com/$repo.git" $repo
      fi
    )
    fi
  ) 2>&1 | cat > $logs/$repo &
done

wait

cat $logs/**/*
rm -rf $logs

echo
echo "$0 done."
