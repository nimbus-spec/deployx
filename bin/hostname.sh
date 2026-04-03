#!/bin/bash
# bin/hostname.sh - ç”Ÿæˆä¸»æœºå

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_DIR/lib/output.sh"
source "$PROJECT_DIR/config/region-codes.conf"

# é»˜è®¤å€¼
COUNTRY="${COUNTRY:-us}"
REGION="${REGION:-unknown}"
MERCHANT="${MERCHANT:-unknown}"
NET_TYPE="${NET_TYPE:-unknown}"

main() {
    # åŒºåŸŸçŸ­ç è½¬æ¢
    local region_code="${REGION_CODES[$REGION]:-${REGION:0:3}}"
    region_code=$(echo "$region_code" | tr '[:upper:]' '[:lower:]')
    COUNTRY=$(echo "$COUNTRY" | tr '[:upper:]' '[:lower:]')
    
    # éšæœºå­—ç¬¦ä¸²
    local rand8=$(head /dev/urandom 2>/dev/null | tr -dc 'a-z0-9' | head -c 8)
    
    # ç”Ÿæˆä¸»æœºå
    local hostname="${COUNTRY}-${region_code}-${NET_TYPE}-${MERCHANT}-${rand8}"
    
    echo "HOSTNAME=$hostname"
}

main "$@"
