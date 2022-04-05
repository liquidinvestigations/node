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
    if [ -d testdata ]; then
      rm -rf testdata
    fi
    devnull "git clone https://github.com/liquidinvestigations/testdata testdata"
  ) &

  (
    cd $CLUSTER
    devnull "./bin/docker.sh --rm"
  )

  echo "INSTALL DONE"
  wait
}

case "$ARGUMENT" in
  1)
    wipe
    install


    echo '-------------------------------'
    ./ci/tests/1-hoover
    ;;

  2)
    ./ci/tests/2-backup-restore
    ;;

  3)
    ./ci/tests/3-wait
    ;;

  *)
    echo "bad arg"
    exit 1
    ;;
esac
