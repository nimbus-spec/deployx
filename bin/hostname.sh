#!/bin/bash
# bin/hostname.sh - Hostname generation

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_DIR/lib/output.sh"
source "$PROJECT_DIR/config/region-codes.conf"

COUNTRY="${COUNTRY:-us}"
REGION="${REGION:-unknown}"
MERCHANT="${MERCHANT:-unknown}"
NET_TYPE="${NET_TYPE:-unknown}"

main() {
    local region_code="${REGION_CODES[$REGION]:-${REGION:0:3}}"
    region_code=$(echo "$region_code" | tr '[:upper:]' '[:lower:]')
    COUNTRY=$(echo "$COUNTRY" | tr '[:upper:]' '[:lower:]')
    
    local rand8=$(head /dev/urandom 2>/dev/null | tr -dc 'a-z0-9' | head -c 8)
    
    local hostname="${COUNTRY}-${region_code}-${NET_TYPE}-${MERCHANT}-${rand8}"
    
    echo "HOSTNAME=$hostname"
}

main "$@"
