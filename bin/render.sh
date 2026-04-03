#!/bin/bash
# bin/render.sh - Template rendering
# Usage: ./bin/render.sh -t TEMPLATE [-v KEY=VALUE]...
# Example: ./bin/render.sh -t user-data.tpl -v HOSTNAME=test -v SSH_KEY="ssh-rsa ..."
# Output: Rendered template to stdout

set -e

usage() {
    cat << EOF
Usage: $0 [options]
Options:
    -t TEMPLATE    Template file path
    -v KEY=VALUE   Variable assignments (can be repeated)
    -o OUTPUT      Output file (default: stdout)
    -h             Show this help

Example:
    $0 -t template.tpl -v HOSTNAME=test -v PORT=22
EOF
}

TEMPLATE=""
OUTPUT=""
declare -a VARS

while getopts "t:v:o:h" opt; do
    case $opt in
        t) TEMPLATE="$OPTARG" ;;
        v) VARS+=("$OPTARG") ;;
        o) OUTPUT="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

[[ -z "$TEMPLATE" ]] && { echo "Error: -t TEMPLATE required"; exit 1; }
[[ ! -f "$TEMPLATE" ]] && { echo "Error: Template not found: $TEMPLATE"; exit 1; }

# Export variables for envsubst
for var in "${VARS[@]}"; do
    key="${var%%=*}"
    value="${var#*=}"
    export "$key"="$value"
done

# Use envsubst to replace ${VAR} style placeholders
# Convert {{ VAR }} to ${VAR} for envsubst
temp_file=$(mktemp)
sed 's/{{ *\([A-Za-z_][A-Za-z0-9_]*\) *}}/${\1}/g' "$TEMPLATE" > "$temp_file"

result=$(envsubst < "$temp_file")
rm -f "$temp_file"

# Output
if [[ -n "$OUTPUT" ]]; then
    echo "$result" > "$OUTPUT"
else
    echo "$result"
fi
