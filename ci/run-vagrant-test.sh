#!/bin/bash -e

cd "$( dirname "${BASH_SOURCE[0]}" )"

set -x
export VAGRANT_DOTFILE_PATH=$(mktemp -d --tmpdir VAGRANT_DOTFILE_XXXXXXXX)
export VAGRANT_DEFAULT_PROVIDER=vmck
export VAGRANT_CHECKPOINT_DISABLE=true
export VAGRANT_BOX_UPDATE_CHECK_DISABLE=true

FILENAME=$(basename -- "$PROVISION")
echo $VMCK_URL
export VMCK_NAME="$DRONE_REPO_NAME:$DRONE_BRANCH#$DRONE_BUILD_NUMBER-$FILENAME"

TIMEOUT_MIN=30
RETRIES=3
set +x

function print_section() {
  set +x
  echo
  echo '-----------------------------------------'
  echo "| $1"
  echo '-----------------------------------------'
}

function vagrant_up() {
  set +e
  vagrant up --no-provision || echo "vagrant up failed, VM might still work"
  echo "sudo shutdown +$TIMEOUT_MIN" | vagrant ssh
  sshret=$?
  if [ 0 -eq $sshret ]; then
    return 0
  else
    vagrant destroy -f || ( sleep 3 && vagrant destroy -f ) || true
    return 1
  fi
}

function retry_vagrant_up() {
  for i in $(seq 1 $RETRIES); do
    print_section "Starting vagrant... (try #$i/$RETRIES)"
    if vagrant_up; then
      return 0
    fi
    sleep 15
  done
  echo "Vagrant failed after $RETRIES tries"
  exit 1
}

retry_vagrant_up

print_section "Run Script"
set +e
set -x
vagrant provision
ret=$?
set +x

print_section "Stats"
vagrant ssh <<'EOF'
for cmd in "uname -a" "w" "free -h" "df -h"; do
  echo
  echo "$cmd"
  $cmd 2>&1
done
EOF

print_section "Destroying Vagrant"
vagrant destroy -f || echo "vagrant destroy failed, but we don't care"
exit $ret
