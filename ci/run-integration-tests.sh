#!/bin/bash -ex

cd "$(dirname ${BASH_SOURCE[0]})/.."
ARGUMENT=$1

CLUSTER=/opt/cluster

function docker_killall {
  docker kill $(docker ps -q) >/dev/null 2>/dev/null || true
  docker rm -f $(docker ps -qa) >/dev/null 2>/dev/null || true
  docker system prune --volumes
}

function devnull {
  bash -exc " $@ " 2>&1 >/dev/null
}


function wipe {
  devnull "pipenv --rm || true"
  devnull "docker kill cluster || true"
  docker_killall
  sudo rm -rf $CLUSTER/var/* || true
  sudo rm -rf /opt/node/volumes/* || true
  sudo rm -rf /app-test/backups || true
  sudo rm -rf /app-test/backup || true

  echo "WIPE DONE"
}


function install {

  mkdir -p /opt/node/collections
  mkdir -p /opt/node/volumes
  mkdir -p ../backups

  devnull "pipenv install"  &

  devnull "git fetch --tags"  &

  (
    cd /opt/node/collections
    if ! [ -d testdata ]; then
      devnull "git clone https://github.com/liquidinvestigations/testdata testdata"
    fi
    cd testdata
    devnull "git pull origin master"
  ) &

  (
    cd $CLUSTER
    devnull "./bin/docker.sh --rm"
  )

  echo "INSTALL DONE"
  wait
}


if [[ "$ARGUMENT" == "1" ]]; then
  wipe
  install


  echo '-------------------------------'
  ./ci/tests/1-hoover
fi

if [[ "$ARGUMENT" == "2" ]]; then
  ./ci/tests/2-backup-restore
fi

if [[ "$ARGUMENT" == "3" ]]; then
  ./ci/tests/3-wait
fi
