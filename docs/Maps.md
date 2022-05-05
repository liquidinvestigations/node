# Download Maps Data

For self-hosted maps, a download of at least 130 GB is required. The source
servers (Internet Archive) are sometimes slow, so this may take a few days.
Because of this, downloading and redistributing the data should be done
manually, and the feature can be enabled after the download is done.


## Installation Steps

Create a directory in the `liquid_volume` folder, under `hoover`, called `osmdata`, and inside it another one called `input`. For the default path, this means:

```
sudo mkdir -p /opt/node/volumes/hoover/osmdata/input
sudo chown -R $USER: /opt/volumes/hoover/osmdata
```

Then, download the tiles file (90 GB) into the `osmdata` directory:

```
cd /opt/volumes/hoover/osmdata
wget https://archive.org/download/osm-vector-mbtiles/2020-10-planet-14.mbtiles
```


In parallel, you can download the OSM Names and build the Geo Names Index, which will generate 40 GB of data.

```
cd /opt/volumes/hoover/osmdata/input
wget https://github.com/OSMNames/OSMNames/releases/download/v2.0.4/planet-latest_geonames.tsv.gz

# unpack it
gunzip planet-latest_geonames.tsv.gz
mv planet-latest_geonames.tsv data.tsv

# go to parent dir and build index
cd ..
time docker run --rm -v $(pwd):/data/ klokantech/osmnames-sphinxsearch:2.0.6 bash sphinx-reindex.sh force
```

-----

You should get something like this:
```
user@server:/opt/node/volumes/hoover/osmdata$ du -ahd1 .
396K	./wget-log
84G	./2020-10-planet-14.mbtiles
34G	./index
6.4G	./input
124G	.
```

After both steps are done, you can enable the feature using this config flag: [[liquid]hoover_maps_enabled = true](https://github.com/liquidinvestigations/node/blob/63b0f598ba068f0068c362c6682bf54be4701f93/examples/liquid.ini#L138) and re-deploy.
