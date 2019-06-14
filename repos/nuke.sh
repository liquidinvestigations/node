#!/bin/bash

set -ex

find . -type d -mindepth 1 -maxdepth 1 -print0 | xargs -0 rm -rf
