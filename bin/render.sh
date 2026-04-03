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
    -d DELIMITER   Delimiter (default: {{ }})
    -o OUTPUT      Output file (default: stdout)
    -h             Show this help

Example:
    $0 -t template.tpl -v HOSTNAME=test -v PORT=22
    $0 -t template.tpl -v KEY1=val1 -v KEY2=val2 -o output.txt
EOF
}

TEMPLATE=""
DELIMITER="{{ |}}"
OUTPUT=""
declare -a VARS

while getopts "t:v:d:o:h" opt; do
    case $opt in
        t) TEMPLATE="$OPTARG" ;;
        v) VARS+=("$OPTARG") ;;
        d) DELIMITER="$OPTARG" ;;
        o) OUTPUT="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

[[ -z "$TEMPLATE" ]] && { echo "Error: -t TEMPLATE required"; exit 1; }
[[ ! -f "$TEMPLATE" ]] && { echo "Error: Template not found: $TEMPLATE"; exit 1; }

# Parse delimiter
OLD_IFS="$IFS"
IFS='|'
read -r OPEN_DEL CLOSE_DEL <<< "$DELIMITER"
IFS="$OLD_IFS"

# Read template
content=$(cat "$TEMPLATE")

# Apply variables
for var in "${VARS[@]}"; do
    key="${var%%=*}"
    value="${var#*=}"
    
    # Escape special characters for sed (use # as delimiter to avoid / conflicts)
    value_escaped=$(echo "$value" | sed 's/[\/&]/\\&/g')
    
    # Replace {{ KEY }} with value (use # as sed delimiter)
    content=$(echo "$content" | sed "s#${OPEN_DEL}[[:space:]]*${key}[[:space:]]*${CLOSE_DEL}#${value_escaped}#g")
done

# Output
if [[ -n "$OUTPUT" ]]; then
    echo "$content" > "$OUTPUT"
else
    echo "$content"
fi
