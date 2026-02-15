#!/bin/bash

process_json() {
local input_file="$1"
local output_file="$2"

    jq -Sc --slurpfile final .github/final.json '
        ($final[0].outbounds) as $final_outbounds |
        $final_outbounds[1].outbounds as $to_append |
        ($final_outbounds | del(.[0, 1])) as $filtered_final_outbounds |
        . |
        .outbounds[2].outbounds += $to_append |
        .outbounds[1].outbounds += $to_append |
        .outbounds += $filtered_final_outbounds
    ' "$input_file" > "$output_file"
}

if [ ! -f ".github/final.json" ]; then
    echo "Error: final.json not found"
    exit 1
fi

base_configs=(
    "cn"
    "cn-sfw"
    "cn-notun"
    "cn-sfw-notun"
    "ir"
    "ir-sfw"
    "ir-notun"
    "ir-sfw-notun"
    "ru"
    "ru-sfw"
    "ru-notun"
    "ru-sfw-notun"
    "un"
    "un-sfw"
    "un-notun"
    "un-sfw-notun"
)

success_count=0
total_pairs=${#base_configs[@]}

for i in "${base_configs[@]}"; do
    input_file="templates/sing-box/template-${i}.json"
    mkdir -p release/sing-box
    output_file="release/sing-box/${i}.json"

    if [ ! -f "$input_file" ]; then
        echo "Warning: Input file $input_file not found, skipping"
        continue
    fi

    if process_json "$input_file" "$output_file"; then
        ((success_count++))
    fi
done

echo "Processing complete: $success_count/$total_pairs files processed successfully"
