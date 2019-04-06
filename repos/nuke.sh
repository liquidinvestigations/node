#!/bin/bash

set -ex

exec find . -type d -depth 2 -print0 | xargs -0 rm -rf
