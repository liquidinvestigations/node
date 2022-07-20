#!/bin/bash -e

public=''

while getopts c:t:pu: flag
do
    case "${flag}" in
        c) collection="${OPTARG}" ;;
        t) file="${OPTARG}" ;;
        p) public="-p" ;;
        u) user="${OPTARG}"
    esac

uuid=$(./liquid dockerexec hoover:search ./manage.py getuuid $user | tail -1)
./liquid dockerexec hoover:snoop -c $collection -t $file --uuid $uuid --user $user $public
