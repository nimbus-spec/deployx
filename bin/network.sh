#!/bin/bash
# bin/network.sh - Network detection

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_DIR/lib/output.sh"

is_public_ip() {
    local ip="$1"
    local addr="${ip%%/*}"
    
    [[ "$addr" == 10.* ]] && return 1
    [[ "$addr" == 172.1[6-9].* ]] || [[ "$addr" == 172.2[0-9].* ]] || [[ "$addr" == 172.3[0-1].* ]] && return 1
    [[ "$addr" == 192.168.* ]] && return 1
    [[ "$addr" == 127.* ]] && return 1
    return 0
}

main() {
    header "Network Detection"
    
    local eth=$(ip route | grep default | awk '{print $5}' | head -1)
    eth="${eth:-eth0}"
    
    info "Network interface: $eth"
    
    local public_v4=""
    local private_v4=""
    local all_v4=$(ip -4 addr show "$eth" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.[0-9]+){3}/\d+' || echo "")
    
    for addr in $all_v4; do
        if is_public_ip "$addr"; then
            public_v4="$addr"
        else
            private_v4="$addr"
        fi
    done
    
    local public_v6=""
    local all_v6=$(ip -6 addr show "$eth" 2>/dev/null | grep -oP '(?<=inet6\s)[a-f0-9:]+/\d+' || echo "")
    
    for addr in $all_v6; do
        if [[ "$addr" != fe80:* ]]; then
            public_v6="$addr"
        fi
    done
    
    local net_type="unknown"
    if [[ -n "$public_v4" ]] && [[ -n "$public_v6" ]]; then
        net_type="dual"
    elif [[ -n "$public_v4" ]]; then
        net_type="v4"
    elif [[ -n "$public_v6" ]]; then
        net_type="v6"
    elif [[ -n "$private_v4" ]]; then
        net_type="nat"
    fi
    
    local gateway=$(ip -4 route show default 2>/dev/null | awk '{print $3}' | head -1)
    
    info "Network type: $net_type"
    info "Public IPv4: ${public_v4:-None}"
    info "Private IPv4: ${private_v4:-None}"
    info "IPv6: ${public_v6:-None}"
    info "Gateway: ${gateway:-None}"
    
    echo ""
    echo "NET_INTERFACE=$eth"
    echo "NET_TYPE=$net_type"
    echo "PUBLIC_V4=$public_v4"
    echo "PRIVATE_V4=$private_v4"
    echo "PUBLIC_V6=$public_v6"
    echo "GATEWAY=$gateway"
}

main "$@"
