#!/bin/bash
# generate.sh - Generate cloud-init configuration
# Usage: ./generate.sh [--lang LANG] [--output FILE]
# 
# Interactive wizard that generates cloud-init configuration for VPS deployment.
# Follows Unix philosophy: does one thing well, outputs to stdout.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
TPL_DIR="$SCRIPT_DIR/templates"

LANG="${LANG:-en}"
OUTPUT_FILE=""

usage() {
    cat << EOF
Usage: $0 [options]
Options:
    --lang LANG       Language (en, zh) [default: en]
    --output FILE    Output file [default: stdout]
    -h, --help      Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lang) LANG="$2"; shift 2 ;;
            --output) OUTPUT_FILE="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) shift ;;
        esac
    done
}

init_i18n() {
    source "$SCRIPT_DIR/translations/${LANG}.sh" 2>/dev/null || true
}

t() {
    local key="$1"
    echo "${T[$key]:-$key}"
}

select_language() {
    echo ""
    echo "========================================"
    echo " DeployX - VPS Deployment Wizard"
    echo "========================================"
    echo ""
    echo "  1) English"
    echo "  2) Chinese"
    echo ""
    echo -n "Select language [1]: "
    read -r choice
    choice="${choice:-1}"
    
    case "$choice" in
        2) LANG="zh" ;;
        *) LANG="en" ;;
    esac
    
    init_i18n
}

detect() {
    eval "$("$BIN_DIR/detect.sh" 2>/dev/null)" || true
    eval "$("$BIN_DIR/network.sh" 2>/dev/null)" || true
    eval "$("$BIN_DIR/location.sh" 2>/dev/null)" || true
    
    INTERFACE="${INTERFACE:-eth0}"
    NET_TYPE="${NET_TYPE:-v4}"
    COUNTRY="${COUNTRY:-us}"
    CITY="${CITY:-unknown}"
    REGION="${REGION:-unknown}"
}

prompt() {
    local var="$1"
    local label="$2"
    local default="${3:-}"
    local required="${4:-no}"
    
    echo ""
    echo "--- $label ---"
    echo -n "$label [$default]: "
    read -r input
    input="${input:-$default}"
    
    if [[ "$required" == "yes" ]] && [[ -z "$input" ]]; then
        echo "Required"
        prompt "$var" "$label" "$default" "$required"
        return
    fi
    
    eval "$var=\$input"
}

prompt_select() {
    local var="$1"
    local label="$2"
    shift 2
    local opts=("$@")
    
    echo ""
    echo "--- $label ---"
    for i in "${!opts[@]}"; do
        echo "  $((i+1))) ${opts[$i]}"
    done
    echo -n "Select [1]: "
    read -r choice
    choice="${choice:-1}"
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#opts[@]} ]]; then
        eval "$var=\${opts[$((choice-1))]}"
    else
        eval "$var=\${opts[0]}"
    fi
}

generate_hostname() {
    local suffix
    suffix=$(head /dev/urandom 2>/dev/null | tr -dc 'a-z0-9' | head -c 8 || echo "$(date +%s)")
    HOSTNAME="$("$BIN_DIR/hostname.sh" -c "$COUNTRY" -r "$REGION" -n "$NET_TYPE" -m "$MERCHANT" -s "$suffix")"
    HOSTNAME="${HOSTNAME#*=}"
}

generate_network_config() {
    if [[ -n "$PUBLIC_V4" ]]; then
        local ip="${PUBLIC_V4%%/*}"
        local cidr="${PUBLIC_V4#*/}"
        cidr="${cidr:-24}"
        cat << EOF
      addresses:
        - ${ip}/${cidr}
      gateway4: ${GATEWAY:-}
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
EOF
    else
        echo "      dhcp4: true"
    fi
}

generate_runcmd() {
    echo "  - echo 'Host *' > /etc/ssh/sshd_config.d/disable.conf"
    echo "  - echo '    StrictHostKeyChecking no' >> /etc/ssh/sshd_config.d/disable.conf"
    echo "  - systemctl restart sshd"
    
    if [[ "$NOMAD_ROLE" != "none" ]]; then
        "$BIN_DIR/nomad.sh" -r "$NOMAD_ROLE" -n "$HOSTNAME" --runcmd 2>/dev/null || true
    fi
    
    if [[ "$TAILSCALE_ENABLE" == "yes" ]] && [[ -n "$TAILSCALE_KEY" ]]; then
        "$BIN_DIR/tailscale.sh" -k "$TAILSCALE_KEY" -o runcmd 2>/dev/null || true
    fi
}

render_config() {
    local network_config
    network_config=$(generate_network_config)
    
    local runcmd
    runcmd=$(generate_runcmd)
    
    "$BIN_DIR/render.sh" \
        -t "$TPL_DIR/user-data.tpl" \
        -v "HOSTNAME=$HOSTNAME" \
        -v "SSH_KEY=$SSH_KEY" \
        -v "SSH_PORT=$SSH_PORT" \
        -v "PASSWORD_HASH=" \
        -v "NETWORK_CONFIG=$network_config" \
        -v "RUNCMD=$runcmd" \
        -v "NOMAD_ROLE=$NOMAD_ROLE"
}

show_summary() {
    echo ""
    echo "========================================"
    echo " Configuration Summary"
    echo "========================================"
    echo ""
    echo "  Hostname:   $HOSTNAME"
    echo "  SSH Port:   $SSH_PORT"
    echo "  Nomad:      $NOMAD_ROLE"
    echo "  Country:    ${COUNTRY^^}"
    echo "  Merchant:   $MERCHANT"
    echo "  Network:    $NET_TYPE"
    [[ "$TAILSCALE_ENABLE" == "yes" ]] && echo "  Tailscale: enabled"
    echo ""
    [[ "$DD_MODE" == "yes" ]] && echo "  Mode: DD ($DD_IMAGE)" || echo "  Mode: Native ($OS $OS_VERSION)"
    echo ""
}

main() {
    parse_args "$@"
    select_language
    detect
    
    prompt MERCHANT "Provider" "" yes
    prompt SSH_KEY "SSH Public Key" "" yes
    prompt SSH_PORT "SSH Port" "22"
    
    prompt_select NOMAD_ROLE "Nomad Role" "none" "server" "client" "server+client"
    
    echo ""
    echo "--- Tailscale ---"
    echo -n "Configure Tailscale? (y/N): "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        TAILSCALE_ENABLE="yes"
        echo -n "Auth key: "
        read -r TAILSCALE_KEY
    else
        TAILSCALE_ENABLE="no"
        TAILSCALE_KEY=""
    fi
    
    prompt_select MODE "Install Mode" "native" "dd"
    
    if [[ "$MODE" == "dd" ]]; then
        DD_MODE="yes"
        prompt DD_IMAGE "DD Image URL" "" yes
    else
        DD_MODE="no"
        OS="debian"
        OS_VERSION="12"
    fi
    
    generate_hostname
    show_summary
    
    echo -n "Generate config? (Y/n): "
    read -r confirm
    confirm="${confirm:-Y}"
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
    
    local config
    config=$(render_config)
    
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$config" > "$OUTPUT_FILE"
        echo "[INFO] Written to $OUTPUT_FILE"
    else
        echo "$config"
    fi
    
    echo ""
    echo "[INFO] Configuration generated."
}

main "$@"
