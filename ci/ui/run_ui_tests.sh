#!/bin/bash -ex

export PATH=/snap/bin:$PATH
curl --version
wget --version
npm --version
node --version

export LIQUID_URL="https://testbox.liquiddemo.org"
export HOOVER_URL="https://hoover.testbox.liquiddemo.org"
export HOOVER_USER_USERNAME="john"
export HOOVER_USER_EMAIL="john@thebeatles.com"
export HOOVER_USER_PASSWORD="$TEST_ADMIN_PASSWORD"
export HOOVER_ADMIN_USERNAME="admin"
export HOOVER_ADMIN_EMAIL="admin@example.com"
export HOOVER_ADMIN_PASSWORD="$TEST_ADMIN_PASSWORD"

rm -rf liquid-tests || true
git clone https://github.com/liquidinvestigations/liquid-tests
cd liquid-tests
git status
npm i
npm t
