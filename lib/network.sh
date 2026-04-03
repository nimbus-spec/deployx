#!/bin/bash
# lib/network.sh - ç½‘ç»œæ£€æµ‹å‡½æ•°åº“

# èŽ·å–ç½‘ç»œæŽ¥å£
get_default_interface() {
    ip route | grep default | awk '{print $5}' | head -1 || echo "eth0"
}

# èŽ·å–æ‰€æœ‰ IPv4 åœ°å€
get_ipv4_addresses() {
    local eth="${1:-$(get_default_interface)}"
    ip -4 addr show "$eth" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' || echo ""
}

# èŽ·å–æ‰€æœ‰ IPv6 åœ°å€
get_ipv6_addresses() {
    local eth="${1:-$(get_default_interface)}"
    ip -6 addr show "$eth" 2>/dev/null | grep -oP '(?<=inet6\s)[a-f0-9:]+/\d+' || echo ""
}

# åˆ¤æ–­æ˜¯å¦ä¸ºå…¬æœ‰ IP
is_public_ip() {
    local ip="$1"
    local addr="${ip%%/*}"  # åŽ»é™¤ CIDR
    
    # ç§æœ‰ IP èŒƒå›´
    if [[ "$addr" == 10.* ]]; then
        return 1
    elif [[ "$addr" == 172.1[6-9].* ]] || [[ "$addr" == 172.2[0-9].* ]] || [[ "$addr" == 172.3[0-1].* ]]; then
        return 1
    elif [[ "$addr" == 192.168.* ]]; then
        return 1
    elif [[ "$addr" == 127.* ]]; then
        return 1
    fi
    return 0
}

# èŽ·å–å…¬æœ‰ IPv4
get_public_ipv4() {
    local addresses=$(get_ipv4_addresses)
    for addr in $addresses; do
        if is_public_ip "$addr"; then
            echo "$addr"
            return 0
        fi
    done
    echo ""
}

# èŽ·å–ç§æœ‰ IPv4
get_private_ipv4() {
    local addresses=$(get_ipv4_addresses)
    for addr in $addresses; do
        if ! is_public_ip "$addr"; then
            echo "$addr"
            return 0
        fi
    done
    echo ""
}

# èŽ·å–å…¬æœ‰ IPv6
get_public_ipv6() {
    local addresses=$(get_ipv6_addresses)
    for addr in $addresses; do
        # æŽ’é™¤é“¾è·¯æœ¬åœ°åœ°å€
        if [[ "$addr" != fe80:* ]] && [[ "$addr" != fc00:* ]] && [[ "$addr" != fd00:* ]]; then
            echo "$addr"
            return 0
        fi
    done
    echo ""
}

# èŽ·å–ç½‘å…³
get_gateway_v4() {
    ip -4 route show default 2>/dev/null | awk '{print $3}' | head -1 || echo ""
}

get_gateway_v6() {
    ip -6 route show default 2>/dev/null | awk '{print $3}' | head -1 || echo ""
}

# èŽ·å– DNS æœåŠ¡å™¨
get_dns_servers() {
    cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print $2}' | tr '\n' ',' | sed 's/,$//' || echo ""
}

# èŽ·å–ç½‘ç»œç±»åž‹
get_network_type() {
    local public_v4=$(get_public_ipv4)
    local private_v4=$(get_private_ipv4)
    local public_v6=$(get_public_ipv6)
    local has_gateway=$(get_gateway_v4)
    
    if [[ -n "$public_v4" ]] && [[ -n "$public_v6" ]]; then
        echo "dual"      # å…¬æœ‰ IPv4 + IPv6
    elif [[ -n "$public_v4" ]]; then
        echo "v4"        # ä»…å…¬æœ‰ IPv4
    elif [[ -n "$public_v6" ]]; then
        echo "v6"        # ä»…å…¬æœ‰ IPv6
    elif [[ -n "$private_v4" ]] && [[ -n "$has_gateway" ]]; then
        echo "nat"       # NAT (ä»…ç§æœ‰ IP)
    else
        echo "unknown"    # æœªçŸ¥
    fi
}

# æ£€æµ‹ IP ç±»åž‹ (DHCP/Static)
get_ip_type() {
    local eth="${1:-$(get_default_interface)}"
    if ip -4 addr show "$eth" 2>/dev/null | grep -q 'dynamic'; then
        echo "dhcp"
    else
        echo "static"
    fi
}

# æ£€æµ‹ç½‘å¡é€Ÿåº¦
get_network_speed() {
    local eth="${1:-$(get_default_interface)}"
    ethtool "$eth" 2>/dev/null | grep "Speed:" | awk '{print $2}' || echo "unknown"
}

# æ£€æµ‹ MTU
get_mtu() {
    local eth="${1:-$(get_default_interface)}"
    cat "/sys/class/net/$eth/mtu" 2>/dev/null || echo "1500"
}

# å®Œæ•´ç½‘ç»œæ£€æµ‹
detect_network() {
    local eth=$(get_default_interface)
    cat << EOF
NET_INTERFACE=$eth
NET_TYPE=$(get_network_type)
IP_TYPE=$(get_ip_type $eth)
PUBLIC_V4=$(get_public_ipv4)
PRIVATE_V4=$(get_private_ipv4)
PUBLIC_V6=$(get_public_ipv6)
GATEWAY_V4=$(get_gateway_v4)
GATEWAY_V6=$(get_gateway_v6)
DNS_SERVERS=$(get_dns_servers)
NET_SPEED=$(get_network_speed $eth)
MTU=$(get_mtu $eth)
EOF
}
