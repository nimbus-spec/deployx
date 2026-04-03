#!/bin/bash
# generate.sh - VPS Auto Deployment Tool
# Modular design using Unix philosophy

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

source "$SCRIPT_DIR/lib/output.sh"
source "$SCRIPT_DIR/lib/i18n.sh"

i18n_init

# OS options
# Ordered OS list (indexed array for consistent order)
OS_KEYS=(debian ubuntu alpine rocky almalinux fedora dd)

declare -A OS_OPTIONS=(
    ["debian"]="Debian"
    ["ubuntu"]="Ubuntu"
    ["alpine"]="Alpine"
    ["rocky"]="Rocky"
    ["almalinux"]="AlmaLinux"
    ["fedora"]="Fedora"
    ["dd"]="Custom DD Image"
)

declare -A OS_VERSIONS=(
    ["debian"]="12"
    ["ubuntu"]="24.04"
    ["alpine"]="3.21"
    ["rocky"]="9"
    ["almalinux"]="9"
    ["fedora"]="42"
)

select_language() {
    echo ""
    echo "Select language:"
    echo "  1) English"
    echo "  2) Chinese"
    echo ""
    read -p "Choice [1]: " choice
    choice="${choice:-1}"
    case "$choice" in
        2|"zh") i18n_load "zh" ;;
        *) i18n_load "en" ;;
    esac
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
    for key in "${OS_KEYS[@]}"; do
        echo "  $i) ${OS_OPTIONS[$key]}"
        ((i++))
    done
    echo ""
    read -p "$(_ PROMPT_OS_SELECTION)" choice
    choice="${choice:-1}"
    local idx=$((choice - 1))
    if [[ $idx -ge 0 ]] && [[ $idx -lt ${#OS_KEYS[@]} ]]; then
        SELECTED_OS="${OS_KEYS[$idx]}"
    else
        SELECTED_OS="debian"
    fi
}

select_os_version() {
    [[ "$SELECTED_OS" == "dd" ]] && return
    echo ""
    local default="${OS_VERSIONS[$SELECTED_OS]:-12}"
    read -p "Version [$default]: " OS_VERSION
    OS_VERSION="${OS_VERSION:-$default}"
}

select_install_mode() {
    echo ""
    echo "Installation mode:"
    echo "  1) Native Install"
    echo "  2) DD (Disk Image)"
    echo ""
    read -p "Choice [1]: " choice
    choice="${choice:-1}"
    [[ "$choice" == "2" ]] && INSTALL_MODE="dd" || INSTALL_MODE="native"
}

select_dd_image() {
    echo ""
    read -p "DD Image URL: " DD_IMAGE_URL
    [[ -z "$DD_IMAGE_URL" ]] && { error "DD image URL required"; exit 1; }
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
    echo "$(_ SECTION_TAILSCALE)"
    read -p "$(_ PROMPT_TAILSCALE_ENABLED)" TS_ENABLED
    TS_ENABLED="${TS_ENABLED:-no}"
    
    if [[ "$TS_ENABLED" =~ ^(yes|y)$ ]]; then
        read -p "$(_ PROMPT_TAILSCALE_AUTHKEY)" TS_AUTH_KEY
        read -p "$(_ PROMPT_TAILSCALE_ACCEPT_ROUTES)" TS_ACCEPT_ROUTES
        TS_ACCEPT_ROUTES="${TS_ACCEPT_ROUTES:-no}"
    fi
}

select_nomad_role() {
    echo ""
    echo "Nomad Role:"
    echo "  1) Server"
    echo "  2) Client"
    echo "  3) Server + Client"
    echo ""
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
    read -sp "$(_ PROMPT_PASSWORD)" DEPLOY_PASS
    echo ""
    PASSWORD_HASH=$(openssl passwd -6 "$DEPLOY_PASS")
}

show_config_summary() {
    source <("$BIN_DIR/hostname.sh" -c "$COUNTRY" -r "$CITY" -n "$NET_TYPE" -m "$MERCHANT")
    
    header "$(_ SECTION_CONFIRM)"
    cat << EOF
  $(_ LABEL_HOSTNAME): $HOSTNAME
  $(_ LABEL_OS): ${OS_OPTIONS[$SELECTED_OS]}
  Install Mode: $INSTALL_MODE
  $(_ LABEL_MERCHANT): $MERCHANT
  Country: $COUNTRY
  Network: $NET_TYPE
  Nomad Role: $NOMAD_ROLE
  SSH Port: $SSH_PORT
  Tailscale: $([[ "$TS_ENABLED" =~ ^(yes|y)$ ]] && echo "Enabled" || echo "Disabled")
  
  Hardware:
    CPU: ${CPU_CORES} cores
    Memory: ${MEMORY_MB}MB
    Disk: ${DISK_GB}GB
EOF

    [[ "$SELECTED_OS" == "dd" ]] && echo "  DD Image: $DD_IMAGE_URL"
    
    echo ""
}

generate_cloud_config() {
    mkdir -p /tmp/seed
    
    source <("$BIN_DIR/hostname.sh" -c "$COUNTRY" -r "$CITY" -n "$NET_TYPE" -m "$MERCHANT")
    
    # Get SSH key
    if [[ -f "$SSH_KEY_FILE" ]]; then
        SSH_KEY=$(cat "$SSH_KEY_FILE")
    else
        read -p "$(_ INFO_SSH_KEY_MANUAL): " SSH_KEY
    fi
    
    # Build network config
    if [[ -n "$PUBLIC_V4" ]]; then
        NET_CONFIG="      addresses:
        - $PUBLIC_V4
      gateway4: $GATEWAY"
    else
        NET_CONFIG="      dhcp4: true"
    fi
    
    [[ -n "$PUBLIC_V6" ]] && NET_CONFIG="$NET_CONFIG
      dhcp6: true
      accept-ra: true"
    
    NET_CONFIG="$NET_CONFIG
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8"

    # Build runcmd
    local runcmd_parts=()
    runcmd_parts+=("  - systemctl restart sshd")
    runcmd_parts+=("  - apt update")
    runcmd_parts+=("  - DEBIAN_FRONTEND=noninteractive apt upgrade -y")
    runcmd_parts+=("  - timedatectl set-timezone UTC")
    
    # Kernel tuning
    runcmd_parts+=("  - |")
    runcmd_parts+=("    sysctl -w net.core.default_qdisc=fq")
    runcmd_parts+=("    sysctl -w net.ipv4.tcp_congestion_control=bbr")
    runcmd_parts+=("    modprobe tcp_bbr 2>/dev/null || true")
    
    # Nomad
    if [[ "$NOMAD_ROLE" != "none" ]]; then
        while IFS= read -r line; do
            runcmd_parts+=("$line")
        done < <("$BIN_DIR/nomad.sh" -r "$NOMAD_ROLE" -n "$HOSTNAME" --runcmd)
    fi
    
    # Tailscale
    if [[ "$TS_ENABLED" =~ ^(yes|y)$ ]] && [[ -n "$TS_AUTH_KEY" ]]; then
        local accept_flag=""
        [[ "$TS_ACCEPT_ROUTES" =~ ^(yes|y)$ ]] && accept_flag="-a"
        while IFS= read -r line; do
            runcmd_parts+=("$line")
        done < <("$BIN_DIR/tailscale.sh" -k "$TS_AUTH_KEY" $accept_flag)
    fi
    
    runcmd_parts+=("  - cloud-init clean --logs")
    
    local runcmd=$(printf '%s\n' "${runcmd_parts[@]}")
    
    # Render user-data template
    "$BIN_DIR/render.sh" \
        -t "$SCRIPT_DIR/templates/user-data.tpl" \
        -v HOSTNAME="$HOSTNAME" \
        -v PASSWORD_HASH="$PASSWORD_HASH" \
        -v SSH_KEY="$SSH_KEY" \
        -v SSH_PORT="$SSH_PORT" \
        -v NETWORK_CONFIG="$NET_CONFIG" \
        -v RUNCMD="$runcmd" \
        -o /tmp/seed/user-data
    
    # Render meta-data
    "$BIN_DIR/render.sh" \
        -t "$SCRIPT_DIR/templates/meta-data.tpl" \
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
        ${IMAGE_URL:+--img "$DD_IMAGE_URL"} \
        ${SELECTED_OS:+--os "$SELECTED_OS"} \
        ${OS_VERSION:+--version "$OS_VERSION"} \
        --hostname "$HOSTNAME" \
        --ssh-port "$SSH_PORT" \
        --ssh-key "$SSH_KEY" \
        --cloud-data "/tmp/seed/"
}

main() {
    select_language
    
    header "$(_ HEADER_MAIN)"
    
    echo ""
    info "Detecting system..."
    detect_system
    
    section "$(_ SECTION_OS_SELECTION)"
    select_os
    select_os_version
    
    if [[ "$SELECTED_OS" == "dd" ]]; then
        select_install_mode
        select_dd_image
    else
        select_install_mode
    fi
    
    section "$(_ SECTION_CONFIG)"
    select_merchant
    select_ssh
    select_tailscale
    select_nomad_role
    select_password
    
    section "$(_ SECTION_HARDWARE)"
    info "CPU: ${CPU_CORES} cores"
    info "Memory: ${MEMORY_MB}MB"
    info "Disk: ${DISK_GB}GB"
    
    section "$(_ SECTION_NETWORK)"
    info "Interface: $INTERFACE"
    info "Network: $NET_TYPE"
    info "Public IPv4: ${PUBLIC_V4:-None}"
    info "Location: $COUNTRY / $CITY"
    
    show_config_summary
    
    read -p "$(_ PROMPT_CONFIRM)" confirm
    [[ "$confirm" != "$(_ YES)" ]] && exit 0
    
    header "$(_ SECTION_GENERATING)"
    generate_cloud_config
    start_install
}

main "$@"
