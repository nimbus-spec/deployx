#!/bin/bash
# generate.sh - VPS Auto Deployment Tool (Modular)

export LC_ALL=C.UTF-8
export LANG=C.UTF-8
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

source "$SCRIPT_DIR/lib/output.sh"
source "$SCRIPT_DIR/lib/i18n.sh"
i18n_init

# OS list in order
OS_LIST=(
    "debian|Debian"
    "ubuntu|Ubuntu"
    "alpine|Alpine Linux"
    "rocky|Rocky Linux"
    "almalinux|AlmaLinux"
    "fedora|Fedora"
    "dd|Custom DD Image"
)

select_language() {
    echo ""
    echo "Select language:"
    echo "  1) English"
    echo "  2) Chinese"
    read -p "Choice [1]: " lang
    [[ "$lang" == "2" ]] && i18n_load "zh" || i18n_load "en"
}

detect_system() {
    source <("$BIN_DIR/detect.sh")
    source <("$BIN_DIR/network.sh")
    source <("$BIN_DIR/location.sh")
}

select_os() {
    echo ""
    echo "$(_ SECTION_OS_SELECTION)"
    echo ""
    local i=1
    for os in "${OS_LIST[@]}"; do
        name="${os#*|}"
        echo "  $i) $name"
        ((i++))
    done
    echo ""
    read -p "$(_ PROMPT_OS_SELECTION)" choice
    choice="${choice:-1}"
    local idx=$((choice - 1))
    if [[ $idx -ge 0 ]] && [[ $idx -lt ${#OS_LIST[@]} ]]; then
        SELECTED_OS="${OS_LIST[$idx]%%|*}"
    else
        SELECTED_OS="debian"
    fi
    [[ "$SELECTED_OS" == "dd" ]] && select_dd_image
}

select_dd_image() {
    echo ""
    read -p "Enter DD Image URL: " DD_IMAGE_URL
    [[ -z "$DD_IMAGE_URL" ]] && { error "DD image URL required"; exit 1; }
}

select_install_mode() {
    echo ""
    echo "Installation mode:"
    echo "  1) Native Install"
    echo "  2) DD (Disk Image)"
    echo ""
    read -p "Choice [1]: " choice
    [[ "$choice" == "2" ]] && INSTALL_MODE="dd" || INSTALL_MODE="native"
    [[ "$SELECTED_OS" == "dd" ]] && INSTALL_MODE="dd"
}

select_merchant() {
    echo ""
    read -p "$(_ PROMPT_MERCHANT)" MERCHANT
    MERCHANT="${MERCHANT:-unknown}"
}

select_ssh() {
    echo ""
    read -p "$(_ PROMPT_SSH_PORT)" SSH_PORT
    SSH_PORT="${SSH_PORT:-22}"
    read -p "$(_ PROMPT_SSH_KEY)" SSH_KEY_FILE
    SSH_KEY_FILE="${SSH_KEY_FILE:-/root/.ssh/id_rsa.pub}"
}

select_tailscale() {
    echo ""
    read -p "$(_ PROMPT_TAILSCALE_ENABLED)" TS
    [[ "$TS" =~ ^(yes|y)$ ]] && {
        read -p "$(_ PROMPT_TAILSCALE_AUTHKEY)" TS_KEY
        read -p "$(_ PROMPT_TAILSCALE_ACCEPT_ROUTES)" TS_ROUTES
        TS_ENABLED="yes"
    }
}

select_nomad() {
    echo ""
    echo "Nomad Role:"
    echo "  1) Server"
    echo "  2) Client"
    echo "  3) Server + Client (all-in-one)"
    read -p "Choice [3]: " choice
    choice="${choice:-3}"
    case "$choice" in
        1) NOMAD_ROLE="server" ;;
        2) NOMAD_ROLE="client" ;;
        *) NOMAD_ROLE="server+client" ;;
    esac
}

select_password() {
    echo ""
    read -sp "$(_ PROMPT_PASSWORD)" PASS
    echo ""
    PASS_HASH=$(openssl passwd -6 "$PASS")
}

show_summary() {
    HOSTNAME=$("$BIN_DIR/hostname.sh" -c "$COUNTRY" -r "$CITY" -n "$NET_TYPE" -m "$MERCHANT" | cut -d= -f2)
    
    header "$(_ SECTION_CONFIRM)"
    echo "  Hostname: $HOSTNAME"
    echo "  OS: ${SELECTED_OS}"
    echo "  Install: $INSTALL_MODE"
    [[ "$SELECTED_OS" == "dd" ]] && echo "  DD URL: $DD_IMAGE_URL"
    echo "  Merchant: $MERCHANT"
    echo "  Country: $COUNTRY / $CITY"
    echo "  Network: $NET_TYPE"
    echo "  Nomad: $NOMAD_ROLE"
    echo "  SSH Port: $SSH_PORT"
    [[ "$TS_ENABLED" == "yes" ]] && echo "  Tailscale: Enabled"
}

generate_config() {
    mkdir -p /tmp/seed
    
    local ssh_key=""
    [[ -f "$SSH_KEY_FILE" ]] && ssh_key=$(cat "$SSH_KEY_FILE") || read -p "SSH key: " ssh_key
    
    local net_conf=""
    if [[ -n "$PUBLIC_V4" ]]; then
        net_conf="addresses: [$PUBLIC_V4]; gateway4: $GATEWAY"
    else
        net_conf="dhcp4: true"
    fi
    [[ -n "$PUBLIC_V6" ]] && net_conf="$net_conf; dhcp6: true"
    
    local kernel_cmd="sysctl -w net.core.default_qdisc=fq net.ipv4.tcp_congestion_control=bbr; modprobe tcp_bbr 2>/dev/null"
    
    local nomad_cmd=""
    [[ "$NOMAD_ROLE" != "none" ]] && nomad_cmd=$("$BIN_DIR/nomad.sh" -r "$NOMAD_ROLE" -n "$HOSTNAME")
    
    local ts_cmd=""
    [[ "$TS_ENABLED" == "yes" ]] && ts_cmd=$("$BIN_DIR/tailscale.sh" -k "$TS_KEY")
    
    "$BIN_DIR/render.sh" -t "$SCRIPT_DIR/templates/user-data.tpl" \
        -v HOSTNAME="$HOSTNAME" \
        -v PASSWORD_HASH="$PASS_HASH" \
        -v SSH_KEY="$ssh_key" \
        -v SSH_PORT="$SSH_PORT" \
        -v NETWORK_CONFIG="$net_conf" \
        -v RUNCMD="$kernel_cmd; $nomad_cmd; $ts_cmd; cloud-init clean" \
        -o /tmp/seed/user-data
    
    "$BIN_DIR/render.sh" -t "$SCRIPT_DIR/templates/meta-data.tpl" \
        -v HOSTNAME="$HOSTNAME" \
        -o /tmp/seed/meta-data
    
    success "$(_ INFO_CONFIG_GENERATED)"
}

start_install() {
    echo ""
    read -p "$(_ PROMPT_START_INSTALL)" confirm
    [[ "$confirm" != "$(_ YES)" ]] && exit 0
    
    info "$(_ INFO_INSTALL_START)"
    
    "$BIN_DIR/install.sh" \
        ${INSTALL_MODE:+--dd} \
        ${DD_IMAGE_URL:+--img "$DD_IMAGE_URL"} \
        ${SELECTED_OS:+--os "$SELECTED_OS"} \
        --hostname "$HOSTNAME" \
        --ssh-port "$SSH_PORT" \
        --ssh-key "$ssh_key" \
        --cloud-data "/tmp/seed/"
}

main() {
    select_language
    header "$(_ HEADER_MAIN)"
    
    echo ""
    info "Detecting system..."
    detect_system
    
    select_os
    select_install_mode
    select_merchant
    select_ssh
    select_tailscale
    select_nomad
    select_password
    
    section "$(_ SECTION_HARDWARE)"
    info "CPU: $CPU_CORES | Memory: $MEMORY_MB MB | Disk: $DISK_GB GB"
    
    section "$(_ SECTION_NETWORK)"
    info "Type: $NET_TYPE | IPv4: ${PUBLIC_V4:-None} | Location: $COUNTRY/$CITY"
    
    show_summary
    
    echo ""
    read -p "$(_ PROMPT_CONFIRM)" confirm
    [[ "$confirm" != "$(_ YES)" ]] && exit 0
    
    header "$(_ SECTION_GENERATING)"
    generate_config
    start_install
}

main "$@"
