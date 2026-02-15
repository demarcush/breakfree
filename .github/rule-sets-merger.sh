#!/usr/bin/env bash

## Copyright (C) 2025 demarcush
## 
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
## 
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
## 
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Exit on error and undefined variables
set -eu

# Configuration
REJECT_RULESETS=("geoip-malware" "geoip-phishing" "geosite-category-ads-all" "geosite-cryptominers" "geosite-malware" "geosite-phishing")
PROXY_RULESETS=()
DIRECT_RULESETS=("geoip-private" "geosite-connectivity-check" "geosite-private")
BASE_URL="https://cdn.jsdelivr.net/gh/chocolate4u/Iran-sing-box-rules@rule-set"

# Function to download and decompile a rule set
download_and_decompile() {
    local rule_name="$1"
    local srs_file="${rule_name}.srs"
    
    echo "Downloading ${rule_name}..."
    if ! curl -fsSL -o "${srs_file}" "${BASE_URL}/${srs_file}"; then
        echo "Error: Failed to download ${rule_name}" >&2
        return 1
    fi
    
    echo "Decompiling ${rule_name}..."
    if ! sing-box rule-set decompile "${srs_file}"; then
        echo "Error: Failed to decompile ${srs_file}" >&2
        return 1
    fi
    
    # Remove the .srs file after successful decompilation
    rm -f "${srs_file}"
}

# Function to check if custom file exists and is valid
check_custom_file() {
    local category="$1"
    local custom_file="${category}_custom.json"
    
    if [ -f "${custom_file}" ]; then
        echo "Found custom ruleset: ${custom_file}"
        # Basic validation - check if it's a non-empty JSON file
        if ! jq empty "${custom_file}" 2>/dev/null; then
            echo "Warning: ${custom_file} is not valid JSON, ignoring" >&2
            return 1
        fi
        if [ ! -s "${custom_file}" ]; then
            echo "Warning: ${custom_file} is empty, ignoring" >&2
            return 1
        fi
        return 0
    fi
    return 1
}

# Function to merge rule sets including custom files
merge_rulesets() {
    local output_file="$1"
    shift
    local rulesets=("$@")
    
    # Check for custom file for this category
    local category="${output_file%.json}"  # Remove .json extension
    local custom_file="${category}_custom.json"
    
    echo "Merging rulesets for ${output_file}..."
    
    # Prepare arguments for sing-box merge command
    local merge_args=()
    
    # Add remote rulesets
    for ruleset in "${rulesets[@]}"; do
        merge_args+=("-c" "${ruleset}.json")
    done
    
    # Add custom file if it exists and is valid
    if check_custom_file "${category}"; then
        echo "Including custom ruleset: ${custom_file}"
        merge_args+=("-c" "${custom_file}")
    fi
    
    if [ ${#merge_args[@]} -eq 0 ]; then
        echo "No rulesets to merge for ${output_file}"
        # If only custom file exists, copy it to output
        if [ -f "${custom_file}" ]; then
            echo "Only custom file exists, copying to ${output_file}"
            cp "${custom_file}" "${output_file}"
            return 0
        fi
        return 0
    fi
    
    echo "Merging ${#rulesets[@]} remote rulesets" \
         "$([ -f "${custom_file}" ] && echo "and 1 custom ruleset into")" \
         "${output_file}..."
    
    if ! sing-box rule-set merge "${output_file}" "${merge_args[@]}"; then
        echo "Error: Failed to merge rulesets into ${output_file}" >&2
        return 1
    fi
}

# Function to process a JSON rule set file
process_json_file() {
    local json_file="$1"
    
    echo "Processing ${json_file}..."
    
    # Check if file exists and is not empty
    if [ ! -f "${json_file}" ]; then
        echo "Warning: ${json_file} does not exist, skipping" >&2
        return 0
    fi
    
    if [ ! -s "${json_file}" ]; then
        echo "Warning: ${json_file} is empty, skipping" >&2
        return 0
    fi
    
    # Basic JSON validation before processing
    if command -v jq >/dev/null 2>&1; then
        if ! jq empty "${json_file}" 2>/dev/null; then
            echo "Error: ${json_file} is not valid JSON, skipping processing" >&2
            return 1
        fi
    fi
    
    # Upgrade the rule set
    echo "  Upgrading..."
    if ! sing-box rule-set upgrade -w "${json_file}"; then
        echo "Warning: Failed to upgrade ${json_file}" >&2
    fi
    
    # Format the rule set
    echo "  Formatting..."
    if ! sing-box rule-set format -w "${json_file}"; then
        echo "Warning: Failed to format ${json_file}" >&2
    fi
    
    # Compile the rule set
    echo "  Compiling..."
    if ! sing-box rule-set compile "${json_file}"; then
        echo "Error: Failed to compile ${json_file}" >&2
        return 1
    fi
    
    echo "  Done!"
}

# Function to create example custom files if they don't exist
create_example_custom_files() {
    for category in reject proxy direct; do
        local custom_file="${category}_custom.json"
        if [ ! -f "${custom_file}" ]; then
            cat > "${custom_file}" << EOF
{
  "version": 1,
  "rules": [
    {
      "domain": ["example.com"],
      "outbound": "${category}"
    }
  ]
}
EOF
            echo "Created example ${custom_file} - customize it with your own rules"
        fi
    done
}

# Main execution
main() {
    echo "Starting rule set processing..."
    
    # Create example custom files if they don't exist
    echo "Checking for custom rule files..."
    create_example_custom_files
    
    # Get all unique rulesets to download
    declare -A unique_rulesets
    for ruleset in "${REJECT_RULESETS[@]}" "${PROXY_RULESETS[@]}" "${DIRECT_RULESETS[@]}"; do
        unique_rulesets["$ruleset"]=1
    done
    
    # Download and decompile all unique rulesets
    for ruleset in "${!unique_rulesets[@]}"; do
            download_and_decompile "${ruleset}"
    done
    
    # Merge rulesets (including custom files) into category files
    merge_rulesets "reject.json" "${REJECT_RULESETS[@]}"
    merge_rulesets "proxy.json" "${PROXY_RULESETS[@]}"
    merge_rulesets "direct.json" "${DIRECT_RULESETS[@]}"
    
    # Process the merged JSON files
    for category in "reject" "proxy" "direct"; do
        json_file="${category}.json"
        if [ -f "${json_file}" ]; then
            process_json_file "${json_file}"
        else
            echo "Note: ${json_file} was not created (no rulesets to merge)"
        fi
    done
    
    # Summary
    echo ""
    echo "=== Processing Summary ==="
    for category in "reject" "proxy" "direct"; do
        json_file="${category}.json"
        custom_file="${category}_custom.json"
        srs_file="${category}.srs"
        
        echo -n "${category}: "
        if [ -f "${json_file}" ]; then
            echo -n "✅ ${json_file}"
            if [ -f "${custom_file}" ]; then
                echo -n " (includes custom rules)"
            fi
            if [ -f "${srs_file}" ]; then
                echo -n " → ${srs_file}"
            fi
            echo ""
        else
            echo "❌ Not created (no rulesets)"
        fi
    done
    
    echo ""
    echo "Rule set processing completed!"
    echo "Customize the *_custom.json files to add your own rules, then rerun this script."
}

# Check for required commands
check_dependencies() {
    local missing_deps=()
    
    if ! command -v sing-box >/dev/null 2>&1; then
        missing_deps+=("sing-box")
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies:" >&2
        for dep in "${missing_deps[@]}"; do
            echo "  - ${dep}" >&2
        done
        echo "Please install missing dependencies before running this script." >&2
        exit 1
    fi
    
    # Optional dependency for JSON validation
    if ! command -v jq >/dev/null 2>&1; then
        echo "Warning: 'jq' not found. JSON validation will be limited." >&2
        echo "Install jq for better JSON processing and validation." >&2
    fi
}

# Run checks and main function
check_dependencies
main
