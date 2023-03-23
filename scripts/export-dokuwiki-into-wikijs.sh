#!/bin/bash -ex

# code snippet comes from https://feedback.js.wiki/wiki/p/import-from-another-wiki and https://stackoverflow.com/a/4774063

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
echo $SCRIPTPATH
# requires bash >= 4.0 to loop through subdirectories
shopt -s globstar

mkdir -p /tmp/dokuwiki-export
cd "${SCRIPTPATH}/../volumes/dokuwiki/data/dokuwiki/data/pages"
echo "Copying dokuwiki content to temporary location for conversion..."
cp -a ./. /tmp/dokuwiki-export

echo "Converting all pages..."
for d in /tmp/dokuwiki-export/**/*.txt; do
    pandoc -o "${d}.md" -f dokuwiki -t markdown_mmd $d
    rm $d
    mv "${d}.md" $d
    rename .txt .md $d
done
echo "Conversion done!"

# disable ** wildcard again
shopt -u globstar

echo "Creating zip archive of all pages..."
cd /tmp/dokuwiki-export
zip -r "${SCRIPTPATH}/../dokuwiki-export.zip"  .
echo "Zip created!"

echo "Removing temporary files..."
rm -r /tmp/dokuwiki-export

echo "Export finished!"

CONTAINER_ID=$(docker ps | grep "liquidinvestigations/wiki.js" | awk '{print $1}')

cd "${SCRIPTPATH}/../"
echo "Uploading the data to wikijs...!"
./liquid shell wikijs:wikijs bash -c 'mkdir -p /tmp/wiki'
docker cp ${SCRIPTPATH}/../dokuwiki-export.zip ${CONTAINER_ID}:/tmp/wiki
./liquid shell wikijs:wikijs bash -c 'unzip /tmp/wiki/dokuwiki-export.zip -d /tmp/wiki && rm /tmp/wiki/dokuwiki-export.zip'

echo "Done!"
echo "Go to your wiki.js admin interface and under 'Storage' enable 'Local File System' with the path /tmp/wiki. Press import everything at the bottom to import all the pages. After that you can disable the 'Local File System again'."
