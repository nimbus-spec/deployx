#!/bin/bash
# bin/location.sh - IP geolocation detection
# Usage: source <(./bin/location.sh) or ./bin/location.sh
# Output: COUNTRY, CITY, REGION

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

detect_location() {
    local country=""
    local city=""
    local region=""
    
    local resp=$(curl -fsSL --max-time 8 "https://ipapi.co/json/" 2>/dev/null)
    
    if [[ -z "$resp" ]]; then
        resp=$(curl -fsSL --max-time 8 "http://ip-api.com/json/" 2>/dev/null)
    fi
    
    if [[ -n "$resp" ]]; then
        country=$(echo "$resp" | grep -o '"country_code":"[^"]*"' | head -1 | cut -d'"' -f4)
        city=$(echo "$resp" | grep -o '"city":"[^"]*"' | head -1 | cut -d'"' -f4)
        region=$(echo "$resp" | grep -o '"region":"[^"]*"' | head -1 | cut -d'"' -f4)
    fi
    
    country="${country:-us}"
    city="${city:-unknown}"
    region="${region:-unknown}"
    
    country=$(echo "$country" | tr '[:upper:]' '[:lower:]')
    city=$(echo "$city" | tr '[:upper:]' '[:lower:]')
    region=$(echo "$region" | tr '[:upper:]' '[:lower:]')
    
    echo "COUNTRY=$country"
    echo "CITY=$city"
    echo "REGION=$region"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_location
else
    eval "$(detect_location)"
fi
