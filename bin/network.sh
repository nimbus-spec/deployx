#!/bin/bash
# bin/network.sh - Network detection
# Usage: source <(./bin/network.sh) or ./bin/network.sh
# Output: INTERFACE, NET_TYPE, PUBLIC_V4, PRIVATE_V4, PUBLIC_V6, GATEWAY

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

is_private_ip() {
    local ip="${1%%/*}"
    
    [[ "$ip" == 10.* ]] && return 0
    [[ "$ip" == 172.1[6-9].* ]] || [[ "$ip" == 172.2[0-9].* ]] || [[ "$ip" == 172.3[0-1].* ]] && return 0
    [[ "$ip" == 192.168.* ]] && return 0
    [[ "$ip" == 127.* ]] && return 0
    [[ "$ip" ==169.254.* ]] && return 0
    
    return 1
}

detect_network() {
    local eth=$(ip route | grep default | awk '{print $5}' | head -1)
    eth="${eth:-eth0}"
    
    PUBLIC_V4=""
    PRIVATE_V4=""
    PUBLIC_V6=""
    GATEWAY=""
    
    local all_v4=$(ip -4 addr show "$eth" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.[0-9]+){3}/\d+' || echo "")
    
    for addr in $all_v4; do
        if is_private_ip "$addr"; then
            PRIVATE_V4="$addr"
        else
            PUBLIC_V4="$addr"
        fi
    done
    
    local all_v6=$(ip -6 addr show "$eth" 2>/dev/null | grep -oP '(?<=inet6\s)[a-f0-9:]+/\d+' || echo "")
    
    for addr in $all_v6; do
        if [[ "$addr" != fe80:* ]] && [[ "$addr" != ::1/* ]]; then
            PUBLIC_V6="$addr"
        fi
    done
    
    GATEWAY=$(ip -4 route show default 2>/dev/null | awk '{print $3}' | head -1)
    
    local net_type="unknown"
    if [[ -n "$PUBLIC_V4" ]] && [[ -n "$PUBLIC_V6" ]]; then
        net_type="dual"
    elif [[ -n "$PUBLIC_V4" ]]; then
        net_type="v4"
    elif [[ -n "$PUBLIC_V6" ]]; then
        net_type="v6"
    elif [[ -n "$PRIVATE_V4" ]]; then
        net_type="nat"
    fi
    
    echo "INTERFACE=$eth"
    echo "NET_TYPE=$net_type"
    echo "PUBLIC_V4=${PUBLIC_V4:-}"
    echo "PRIVATE_V4=${PRIVATE_V4:-}"
    echo "PUBLIC_V6=${PUBLIC_V6:-}"
    echo "GATEWAY=${GATEWAY:-}"
}

get_default_interface() {
    ip route | grep default | awk '{print $5}' | head -1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_network
else
    eval "$(detect_network)"
fi
