#!/bin/bash -ex

id $(whoami)

echo "Installing liquid" > /dev/null

cd /opt/node
sudo chown -R vagrant: .

mkdir volumes
mkdir collections
if ! [ -d collections/testdata ]; then
  git clone https://github.com/liquidinvestigations/testdata collections/testdata
fi

echo "Add some collections, check resources and deploy"
cp examples/liquid.ini .
cat vagrant/liquid-collections.ini >> liquid.ini
sudo apt-get install -qy python3-venv python3-pip
sudo -H pip3 install pipenv
pipenv install
./liquid resources
./liquid deploy

echo "Turn workers off, others on, and deploy"
cp examples/liquid.ini .
cat vagrant/liquid-collections-alt.ini >> liquid.ini
./liquid resources
./liquid deploy

echo "Do a backup"
# until ./liquid dockerexec hoover:snoop ./manage.py workisdone testdata 2>/dev/null; do sleep 5; done
./liquid backup ./backup
ls -aRlh ./backup

zcat backup/collection-testdata/pg.sql.gz | grep -q "PostgreSQL database dump complete"
tar tz < backup/collection-testdata/es.tgz | grep -q 'index.latest'
#tar tz < backup/collection-testdata/blobs.tgz | grep -q '6b/2b/b2ac1b581c3dc6c3c19197b0603a83f2440fb4e2b74f2fe0b76f50e240bf'
./liquid backup --no-es --no-pg --no-apps ./backup2
./liquid backup --no-blobs --no-apps --collection testdata --collection uploads ./backup3
./liquid restore-collection ./backup/collection-testdata testdata2

echo "Remove all collections, gc, restore from backup"
cp -f examples/liquid.ini .
./liquid nomadgc
./liquid deploy --no-secrets
./liquid dockerexec hoover:snoop ./manage.py purge --force
./liquid restore-all-collections ./backup

echo "Restore apps"
./liquid restore-apps ./backup

echo "Restore apps after wipe"
docker kill cluster
docker kill $(docker ps -q)
docker ps
sudo rm -rf /opt/node/volumes/*
sudo rm -rf /opt/cluster/var/*
echo
docker start cluster
docker exec cluster ./cluster.py wait
./liquid deploy
./liquid restore-all-collections ./backup
./liquid restore-apps ./backup

echo "Disable some apps, deploy"
cp -f examples/liquid.ini .
cat vagrant/liquid-apps.ini >> liquid.ini
./liquid deploy

echo "Disable some more apps, gc"
echo "default_app_status = off" >> liquid.ini
./liquid deploy

echo "Liquid provisioned successfully." > /dev/null
