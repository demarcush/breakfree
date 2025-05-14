#!/bin/bash

# Configuration
BASE_URL="https://cdn.jsdelivr.net/gh/chocolate4u/Iran-sing-box-rules@rule-set"
OUTPUT_DIR="release/rule-sets"
SING_BOX_PATH="sing-box"
CAT_DIR="templates/rule-sets/categories"
TEMP_DIR=".temp"
DEFAULT_FILE="templates/rule-sets/default.json"

# Create directories if they don't exist
mkdir -p "$TEMP_DIR" "$OUTPUT_DIR"

# Function to process a single template file
process_cats() {
	local basename
	basename=$(basename "$1" .md)

	echo "Processing $basename..."

    # Process each line in the cat file
    while read i; do

    local url=${BASE_URL}/${i}.srs
    local srs_file=${TEMP_DIR}/${i}.srs
    local json_file=${TEMP_DIR}/${i}.json

    # Download the file
    echo "Downloading $url..." && \
	    curl -fsSL -o "$srs_file" "$url" || echo "Failed to download $i"

    # Decompile the downloaded file
    echo "Decompiling $i..." && \
	    "$SING_BOX_PATH" rule-set decompile "$srs_file" -o "$json_file" || echo "Failed to decompile $i"
	done < <(cat "$1")

    # Merge the JSON file
    echo "Merging $json_file..." && \
	    jq -s '.[]' "$DEFAULT_FILE" "$1" > "$OUTPUT_DIR/json/$basename.json"

    # Recompile
    for i in $(ls "$OUTPUT_DIR/json/*.json"); do
	    "$SING_BOX_PATH" rule-set compile "$i" -o "$OUTPUT_DIR/srs/$basename.srs"
    done < <(cat "$1")

    echo "Finished processing $basename."
    echo "Output files:"
    echo "  - Merged JSON: $OUTPUT_DIR/json/$basename.json"
    echo "  - Compiled ruleset: $OUTPUT_DIR/srs/$basename.srs"
}

# Main processing loop
for i in $(ls "$CAT_DIR"/*.md); do
    process_cats "$i"
done

# Cleanup
#rm -rf "$TEMP_DIR" #TODO

echo "All rule-set files processed."
