#!/bin/bash -ex

#export LIQUID_VOLUMES=/data/liquid-volumes
#export LIQUID_COLLECTIONS=/opt/node/collections
#export LIQUID_COLLECTIONS_NEW=/opt/node/collections2

if [[ ! -z $(docker ps -q) ]]; then
        exit 1
fi

if [[ -z "$LIQUID_VOLUMES" || -z "$LIQUID_COLLECTIONS" || -z "$LIQUID_COLLECTIONS_NEW" ]]; then
        exit 1
fi

for old in $(find -L "$LIQUID_COLLECTIONS" -mindepth 1 -maxdepth 1 -type d,l); do
        name="$(basename "$old")"
        new="$LIQUID_COLLECTIONS_NEW/$name/data"

        mkdir -p "$new"

        set +x
        for item in $(find -L $old -maxdepth 1 -mindepth 1); do
                mv -v $item -t $new
        done
        set -x
done

for collection in $(find -L "$LIQUID_VOLUMES/collections" -mindepth 1 -maxdepth 1 -type d,l); do
        name="$(basename "$collection")"
        old="$collection/blobs"
        new="$LIQUID_VOLUMES/snoop/blobs/$name"

        mkdir -p "$new"

        set +x
        for item in $(find -L $old -maxdepth 1 -mindepth 1); do
                mv -v "$item" -t "$new"
        done
        set -x
done
