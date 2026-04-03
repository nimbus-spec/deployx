#!/bin/bash
# bin/hostname.sh - Hostname generation
# Usage: ./bin/hostname.sh -c COUNTRY -r REGION -n NET_TYPE -m MERCHANT [-s SUFFIX]
# Output: HOSTNAME=<generated-hostname>

set -e

usage() {
    cat << EOF
Usage: $0 [options]
Options:
    -c COUNTRY     Country code (e.g., jp, us)
    -r REGION      Region/city code (e.g., tyo, sgp)
    -n NET_TYPE    Network type (v4, v6, dual, nat)
    -m MERCHANT    Merchant/provider name
    -s SUFFIX      Optional suffix (default: random 8 chars)
    -h             Show this help
EOF
}

generate_hostname() {
    local country="${COUNTRY:-us}"
    local region="${REGION:-unknown}"
    local net_type="${NET_TYPE:-v4}"
    local merchant="${MERCHANT:-unknown}"
    local suffix="${SUFFIX:-}"
    
    country=$(echo "$country" | tr '[:upper:]' '[:lower:]')
    region=$(echo "$region" | tr '[:upper:]' '[:lower:]')
    net_type=$(echo "$net_type" | tr '[:upper:]' '[:lower:]')
    merchant=$(echo "$merchant" | tr '[:upper:]' '[:lower:]')
    
    if [[ -z "$suffix" ]]; then
        suffix=$(head /dev/urandom 2>/dev/null | tr -dc 'a-z0-9' | head -c 8)
    fi
    
    echo "HOSTNAME=${country}-${region}-${net_type}-${merchant}-${suffix}"
}

while getopts "c:r:n:m:s:h" opt; do
    case $opt in
        c) COUNTRY="$OPTARG" ;;
        r) REGION="$OPTARG" ;;
        n) NET_TYPE="$OPTARG" ;;
        m) MERCHANT="$OPTARG" ;;
        s) SUFFIX="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

generate_hostname
