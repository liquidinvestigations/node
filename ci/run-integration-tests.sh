#!/bin/bash -ex

cd "$(dirname ${BASH_SOURCE[0]})/.."
CLUSTER=/opt/cluster

function docker_killall {
  docker kill $(docker ps -q) >/dev/null 2>/dev/null || true
}

function devnull {
  bash -exc " $@ " 2>&1 >/dev/null
}


function wipe {
  devnull "pipenv --rm || true" &
  devnull "docker kill cluster || true"
  docker_killall
  devnull "sudo rm -rf $CLUSTER/var/* || true" &
  devnull "sudo rm -rf /opt/node/volumes ../backups || true" &

  wait
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
      devnull "git clone https://github.com/liquidinvestigations/testdata collections/testdata"
    fi
    cd testdata
    devnull "git pull origin master"
  ) &

  (
    cd $CLUSTER
    devnull "./bin/docker.sh --rm"
  )

  wait
}


# leave cadavers on testing server
# trap wipe EXIT

wipe
install


echo '-------------------------------'
./ci/tests/1-hoover
