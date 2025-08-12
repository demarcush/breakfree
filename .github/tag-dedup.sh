#!/bin/bash

# Check if input file is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <input_json_file>"
    exit 1
fi

input_file="$1"
temp_file="${input_file}.tmp"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install jq first."
    exit 1
fi

# Process the JSON file
duplicates_info=$(jq '
    def check_duplicates(path):
        if has("outbounds") and (.outbounds | length) > path then
            .outbounds[path].outbounds | 
            group_by(.) | 
            map(select(length > 1)) | 
            flatten | 
            unique
        else
            []
        end;
    
    {
        "duplicates_in_1": check_duplicates(1),
        "duplicates_in_2": check_duplicates(2)
    }
' "$input_file")

# Extract duplicate information
dups1=$(echo "$duplicates_info" | jq '.duplicates_in_1')
dups2=$(echo "$duplicates_info" | jq '.duplicates_in_2')

# Check if duplicates were found
if [ "$(echo "$dups1" | jq 'length')" -gt 0 ] || [ "$(echo "$dups2" | jq 'length')" -gt 0 ]; then
    echo "Duplicate entries found:"
    
    if [ "$(echo "$dups1" | jq 'length')" -gt 0 ]; then
        echo "In outbounds[1].outbounds:"
        echo "$dups1" | jq -r '.[]'
        echo ""
    fi
    
    if [ "$(echo "$dups2" | jq 'length')" -gt 0 ]; then
        echo "In outbounds[2].outbounds:"
        echo "$dups2" | jq -r '.[]'
        echo ""
    fi
    
    # Remove duplicates and create new file
    jq '
        def remove_duplicates(path):
            if has("outbounds") and (.outbounds | length) > path then
                .outbounds[path].outbounds |= unique
            else
                .
            end;
        
        remove_duplicates(1) | remove_duplicates(2)
    ' "$input_file" > "$temp_file"
    
    # Replace original file
    mv "$temp_file" "$input_file"
    echo "Duplicates removed. Updated file saved to $input_file"
else
    echo "No duplicate entries found in outbounds[1].outbounds or outbounds[2].outbounds"
fi
