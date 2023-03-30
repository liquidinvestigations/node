#!/bin/bash -e

# code snippet comes from https://feedback.js.wiki/wiki/p/import-from-another-wiki

cd "$(dirname ${BASH_SOURCE[0]})/.."

# requires bash >= 4.0 to loop through subdirectories
shopt -s globstar

EXPORT_TMP_PATH=/tmp/liquid-export-dokuwiki-into-wikijs
EXPORT_TMP_PATH_ZIP=/tmp/liquid-export-dokuwiki-into-wikijs.zip

if [ -z "$IMPORT_DOKU_ROOT" ]; then
    IMPORT_DOKU_ROOT=/opt/node/volumes/dokuwiki
    echo "Set default env IMPORT_DOKU_ROOT=$IMPORT_DOKU_ROOT"
    if [ ! -d "$IMPORT_DOKU_ROOT" ]; then
	echo "ERROR: IMPORT_DOKU_ROOT env does not point to directory"
	exit 1
    fi
fi

if [ -z "$PANDOC" ]; then
    PANDOC=pandoc
    echo "Set default env PANDOC=$PANDOC"
    if [ ! -f "$PANDOC" ]; then
	echo "ERROR: PANDOC env does not point to file"
	exit 1
    fi
fi

rm -rf $EXPORT_TMP_PATH
rm -rf $EXPORT_TMP_PATH_ZIP

mkdir -p $EXPORT_TMP_PATH
(
    cd "$IMPORT_DOKU_ROOT/data/dokuwiki/data/pages"
    echo "Copying dokuwiki content to temporary location for conversion..."
    cp -a ./. $EXPORT_TMP_PATH
)

echo "" > "export-errors"

ORIGINAL_COUNT="$(find $EXPORT_TMP_PATH -type f -name '*.txt' | wc -l)"
echo "Original file count: $ORIGINAL_COUNT"

echo "Converting all pages to html"
for d in $EXPORT_TMP_PATH/**/*.txt; do
    title=`basename "${d%.txt}"`
    date="$(date -Isecond -u | cut -d'+' -f1).000Z"
    new_d="${d%.txt}.html"
    new_d_md="${d%.txt}.md"
    new_d_tmp="${d%.txt}.html.tmp"
    # Use Pandoc into temp file
    (
	echo "$title"
	$PANDOC -o "$new_d_tmp" -f dokuwiki -t html "$d"
	    # Start file with special comment for visual editor
	    echo "<!--
title: $title
description: 
published: true
date: $date
tags: 
editor: ckeditor
dateCreated: $date
-->

" > "$new_d"
	    cat "$new_d_tmp" >> "$new_d"
	    rm -f "$new_d_tmp"
    ) || (
	echo "ERROR: FAILED: $d"
	echo "$d" >> "export-errors"
	cp "$d" "$new_d_md"
    )

    rm -f "$d"
done
echo "Conversion done."

# disable ** wildcard again
shopt -u globstar

FINAL_COUNT="$(find $EXPORT_TMP_PATH -type f -name '*.html' | wc -l)"
FINAL_COUNT_md="$(find $EXPORT_TMP_PATH -type f -name '*.md' | wc -l)"
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
echo "Original file count: $ORIGINAL_COUNT"
echo "Final file count (VISUAL): $FINAL_COUNT"
echo "Final file count (MARKDOWN FALLBACK IN CASE OF ERRORS): $FINAL_COUNT_md"
echo
echo "
- Go to your wiki.js admin interface
- Under 'Module > Storage' (link is '/a/storage')
- Under 'Local File System'
	- edit Path: '/tmp/wiki'
	- click 'Activate' button (blue one, top right)
	- click 'Save' button (green one, top right)
- Wait until all $ORIGINAL_COUNT pages are loaded
	- Go to 'Administration' > 'Dashboards'

- Press 'Import Everything' at the bottom
- Disable the 'Local File System' again
"
