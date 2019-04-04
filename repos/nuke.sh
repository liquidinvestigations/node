#!/bin/bash

set -ex

exec find . -type d -depth 2 -delete
