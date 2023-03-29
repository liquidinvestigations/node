#!/bin/bash -ex

# code snippet comes from https://feedback.js.wiki/wiki/p/import-from-another-wiki

cd "$(dirname ${BASH_SOURCE[0]})/.."

# requires bash >= 4.0 to loop through subdirectories
shopt -s globstar

EXPORT_TMP_PATH=/tmp/liquid-export-dokuwiki-into-wikijs
EXPORT_TMP_PATH_ZIP=/tmp/liquid-export-dokuwiki-into-wikijs.zip
IMPORT_DOKU_ROOT=/opt/node/volumes/dokuwiki

rm -rf $EXPORT_TMP_PATH
rm -rf $EXPORT_TMP_PATH_ZIP

mkdir -p $EXPORT_TMP_PATH
(
    cd "$IMPORT_DOKU_ROOT/data/dokuwiki/data/pages"
    echo "Copying dokuwiki content to temporary location for conversion..."
    cp -a ./. $EXPORT_TMP_PATH
)

echo "Converting all pages to md..."
for d in $EXPORT_TMP_PATH/**/*.txt; do
    new_d="${d%.txt}.md"
    pandoc -o "$new_d" -f dokuwiki -t markdown_mmd $d
    rm $d
done
echo "Conversion done."

# disable ** wildcard again
shopt -u globstar

echo "Creating zip archive of all pages..."
(
    cd $EXPORT_TMP_PATH
    zip -r "$EXPORT_TMP_PATH_ZIP"  .
)
echo "Zip created."

echo "Removing temporary files..."
rm -rf $EXPORT_TMP_PATH

echo "Export finished."


echo "Uploading the data to wikijs...."
./liquid shell wikijs:wikijs bash -c 'rm -rf /tmp/wiki && mkdir -p /tmp/wiki'

CONTAINER_TMP_PATH=/tmp/wiki-dokuwiki-export.zip
cat $EXPORT_TMP_PATH_ZIP \
    | docker exec -i cluster ./cluster.py nomad-exec wikijs:wikijs \
    -- bash -c "cat > $CONTAINER_TMP_PATH"
rm -f $EXPORT_TMP_PATH_ZIP

./liquid shell wikijs:wikijs \
    -- bash -c "unzip $CONTAINER_TMP_PATH -d /tmp/wiki -o && rm -f $CONTAINER_TMP_PATH"


set +x
echo
echo "Done."
echo
echo '
- Go to your wiki.js admin interface
- Under "Module > Storage" link "/a/storage" enable "Local File System" with the path:

                /tmp/wiki

- Press "Import Everything" at the bottom
- Disable the "Local File System" again
'
