#!/bin/bash -ex

cd "$( dirname "${BASH_SOURCE[0]}" )"

( ./run-vagrant-test.sh ) || ( echo "trying again... " && sleep 66 && ./run-vagrant-test.sh )
