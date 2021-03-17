#!/bin/bash -e

cd "$( dirname "${BASH_SOURCE[0]}" )"/..

exportdir=''
rmbackups=''
keepdays=60
backupdir=`date +"%Y%m%d-%H%M"`

while [[ $# -gt 0 ]]; do
  arg=$1
  shift
  case "$arg" in
    "--rm") rmbackups=1 ;;
    "--dir") exportdir=$1; shift ;;
    "--days") keepdays=$1; shift ;;
    *) echo "Unknown option $arg" >&2; exit 1
  esac
done

if [ -z $exportdir ]; then
  echo "Usage: ${BASH_SOURCE[0]} --dir exportdir [--rm] [--days N]" >&2
  echo "  --dir      backup directory, a date based subfolder will be added, e.g. exportdir/$backupdir" >&2
  echo "  --rm       remove old backups, default disabled" >&2
  echo "  --days N   remove backups older than N days, default 60 days" >&2
  exit 1
fi

export PATH=/usr/local/bin:/home/$(whoami)/.local/bin:$PATH
mkdir -p $exportdir/$backupdir
./liquid backup --no-collections $exportdir/$backupdir

if [ ! -z $rmbackups ]; then
  echo "Removing backups older than $keepdays days..."
  find $exportdir -maxdepth 1 -type d -mtime +$keepdays -exec rm -rf {} \;
fi
