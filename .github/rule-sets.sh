#!/bin/bash

# Configuration
BASE_URL="https://cdn.jsdelivr.net/gh/chocolate4u/Iran-sing-box-rules@rule-set"
SING_BOX_PATH="sing-box"

TEMPLATES_DIR="templates/rule-sets"
OUTPUT_DIR="release/rule-sets"
TEMP_DIR=".temp"

CAT_DIR=""$TEMPLATES_DIR"/categories"

# Create directories if they don't exist
mkdir -p "$OUTPUT_DIR" "$TEMP_DIR" "$CAT_DIR"

# Function to process a single template file
process_cats() {
	echo "Processing "$i"..."

	# Process each line in the cat file
	while read -r cat_name; do
		url=${BASE_URL}/${cat_name}.srs
		srs_file=${TEMP_DIR}/${cat_name}.srs
		json_file=${TEMP_DIR}/${cat_name}.json

		# Download the file
		echo "Downloading $url..." && \
			curl -fsSL -o "$srs_file" "$url" || echo "Failed to download $i"

		# Decompile the downloaded file
		echo "Decompiling $i..." && \
			"$SING_BOX_PATH" rule-set decompile "$srs_file" -o "$json_file" || echo "Failed to decompile $i"
	done < <(cat "$1")

	echo "Finished processing "$i"."
}

# Main processing loop
for i in $(ls "$CAT_DIR"/*.md); do
    process_cats "$i"
done

# Merging
for i in $CAT_DIR/*.md; do
	basename=$(basename "$i" .md)
	cat_names=$(sed 's|^|'"$TEMP_DIR"'/|; s|$|.json|' "$i")
	echo "Merging $basename..." && \
		jq -n 'reduce inputs as $file (input; .rules[0].rules += $file.rules)' "$TEMPLATES_DIR"/default.json $cat_names > "$OUTPUT_DIR/$basename.json"
done

# Mixing
for i in $OUTPUT_DIR/direct-*; do
	echo "Mixing $(basename $i .json) with direct.jsons..." && \
		jq -n 'reduce inputs as $file (input; .rules[0].rules += $file.rules[0].rules)' $i $TEMPLATES_DIR/direct.json $OUTPUT_DIR/direct.json > ${i}.new && mv ${i}.new "$i"
done
for i in $OUTPUT_DIR/proxy-*; do
	echo "Mixing $(basename $i .json) with proxy.jsons..." && \
		jq -n 'reduce inputs as $file (input; .rules[0].rules += $file.rules[0].rules)' $i $TEMPLATES_DIR/proxy.json $OUTPUT_DIR/proxy.json > ${i}.new && mv ${i}.new "$i"
done

# Recompile
for i in "$OUTPUT_DIR"/*.json; do
	basename=$(basename "$i" .json)
	"$SING_BOX_PATH" rule-set compile "$i" -o "$OUTPUT_DIR/$basename.srs"
done

# Cleanup
rm -rvf "$TEMP_DIR"

echo "All rule-set files processed."
