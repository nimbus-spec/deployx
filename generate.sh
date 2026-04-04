#!/bin/bash
# generate.sh - DeployX Main Wizard
# Usage: ./generate.sh [--lang LANG] [--dd] [--execute]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
LIB_DIR="$SCRIPT_DIR/lib"
TPL_DIR="$SCRIPT_DIR/templates"

source "$LIB_DIR/i18n.sh"

LANG="${LANG:-en}"
DD_MODE="no"
EXECUTE_MODE="no"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lang) LANG="$2"; shift 2 ;;
            --dd) DD_MODE="yes"; shift ;;
            --execute) EXECUTE_MODE="yes"; shift ;;
            *) shift ;;
        esac
    done
}

init_i18n() {
    source "$SCRIPT_DIR/translations/${LANG}.sh" 2>/dev/null || true
}

t() {
    local key="$1"
    local val="${T[$key]:-}"
    if [[ -n "$val" ]]; then
        echo "$val"
    else
        echo "$key"
    fi
}

header() {
    echo ""
    echo "========================================"
    echo " $1"
    echo "========================================"
}

info() {
    echo "[INFO] $1"
}

error() {
    echo "[ERROR] $1" >&2
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
    
    local valid=0
    while [[ $valid -eq 0 ]]; do
        echo -n "Select language [1]: "
        read -r choice
        choice="${choice:-1}"
        
        case "$choice" in
            1) LANG="en"; valid=1 ;;
            2) LANG="zh"; valid=1 ;;
            *) echo "Invalid selection" ;;
        esac
    done
    
    init_i18n
}

detect_hardware() {
    info "$(t DETECT_HW "Detecting hardware...")"
    eval "$("$BIN_DIR/detect.sh" 2>/dev/null)" || true
}

detect_network() {
    info "$(t DETECT_NET "Detecting network...")"
    eval "$("$BIN_DIR/network.sh" 2>/dev/null)" || true
    INTERFACE="${INTERFACE:-eth0}"
    NET_TYPE="${NET_TYPE:-v4}"
}

detect_location() {
    info "$(t DETECT_LOC "Detecting location...")"
    eval "$("$BIN_DIR/location.sh" 2>/dev/null)" || true
    COUNTRY="${COUNTRY:-us}"
    CITY="${CITY:-unknown}"
    REGION="${REGION:-unknown}"
}

prompt_country() {
    echo ""
    echo "--- $(t COUNTRY "Country") ---"
    echo "  $(t AUTO_DETECTED "Auto-detected"): ${COUNTRY^^} (${CITY})"
    echo ""
    echo -n "$(t PROMPT_COUNTRY "Country code") [${COUNTRY}]: "
    read -r input
    COUNTRY="${input:-$COUNTRY}"
}

prompt_merchant() {
    echo ""
    echo "--- $(t MERCHANT "Provider") ---"
    echo ""
    echo -n "$(t PROMPT_MERCHANT "Provider name"): "
    read -r MERCHANT
    while [[ -z "$MERCHANT" ]]; do
        echo "$(t ERROR_NO_MERCHANT "Provider name is required")"
        echo -n "Provider: "
        read -r MERCHANT
    done
}

prompt_ssh_key() {
    echo ""
    echo "--- $(t SSH_KEY "SSH Key") ---"
    echo ""
    
    if [[ -f ~/.ssh/id_rsa.pub ]]; then
        SSH_KEY=$(cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "")
    elif [[ -f ~/.ssh/id_ed25519.pub ]]; then
        SSH_KEY=$(cat ~/.ssh/id_ed25519.pub 2>/dev/null || echo "")
    fi
    
    if [[ -n "$SSH_KEY" ]]; then
        echo "$(t INFO_SSH_KEY_LOADED "SSH key loaded from ~/.ssh/")"
    else
        echo "$(t INFO_SSH_KEY_MISSING "No SSH key found")"
    fi
    
    echo ""
    echo -n "$(t PROMPT_SSH_KEY "Paste SSH public key"): "
    read -r SSH_KEY
    while [[ -z "$SSH_KEY" ]]; do
        echo "$(t ERROR_NO_SSH_KEY "SSH key is required")"
        echo -n "SSH key: "
        read -r SSH_KEY
    done
}

prompt_ssh_port() {
    echo ""
    echo "--- $(t SSH_PORT "SSH Port") ---"
    echo ""
    echo -n "SSH port [22]: "
    read -r SSH_PORT
    SSH_PORT="${SSH_PORT:-22}"
}

prompt_nomad_role() {
    echo ""
    echo "--- $(t NOMAD_ROLE "Nomad Role") ---"
    echo "  1) $(t NOMAD_NONE "None")"
    echo "  2) $(t NOMAD_SERVER "Server")"
    echo "  3) $(t NOMAD_CLIENT "Client")"
    echo "  4) $(t NOMAD_ALL "Server + Client")"
    echo ""
    
    local valid=0
    while [[ $valid -eq 0 ]]; do
        echo -n "Select [4]: "
        read -r choice
        choice="${choice:-4}"
        
        case "$choice" in
            1) NOMAD_ROLE="none"; valid=1 ;;
            2) NOMAD_ROLE="server"; valid=1 ;;
            3) NOMAD_ROLE="client"; valid=1 ;;
            4) NOMAD_ROLE="server+client"; valid=1 ;;
            *) echo "Invalid" ;;
        esac
    done
}

prompt_tailscale() {
    echo ""
    echo "--- $(t TAILSCALE "Tailscale") ---"
    echo ""
    echo -n "Configure Tailscale? (y/N): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        TAILSCALE_ENABLE="yes"
        echo -n "$(t TAILSCALE_KEY "Auth key"): "
        read -r TAILSCALE_KEY
    else
        TAILSCALE_ENABLE="no"
        TAILSCALE_KEY=""
    fi
}

prompt_install_mode() {
    echo ""
    echo "--- $(t INSTALL_MODE "Install Mode") ---"
    echo "  1) DD $(t MODE_DD "Mode")"
    echo "  2) $(t MODE_NATIVE "Native")"
    echo ""
    
    local valid=0
    while [[ $valid -eq 0 ]]; do
        echo -n "Select [2]: "
        read -r choice
        choice="${choice:-2}"
        
        case "$choice" in
            1) 
                DD_MODE="yes"
                prompt_dd_image
                valid=1
                ;;
            2) 
                DD_MODE="no"
                prompt_os_select
                valid=1
                ;;
            *) echo "Invalid" ;;
        esac
    done
}

prompt_dd_image() {
    echo ""
    echo "--- $(t DD_IMAGE "DD Image") ---"
    echo ""
    echo -n "$(t PROMPT_DD_IMAGE "Image URL"): "
    read -r DD_IMAGE
}

prompt_os_select() {
    local os_list=("Debian" "Ubuntu" "Alpine" "Rocky" "CentOS")
    echo ""
    echo "--- $(t OS_SELECT "OS Selection") ---"
    for i in "${!os_list[@]}"; do
        echo "  $((i+1))) ${os_list[$i]}"
    done
    echo ""
    
    local valid=0
    while [[ $valid -eq 0 ]]; do
        echo -n "Select [1]: "
        read -r choice
        choice="${choice:-1}"
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#os_list[@]} ]]; then
            OS="${os_list[$((choice-1))]}"
            valid=1
        fi
    done
    
    OS_VERSION="12"
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
        echo "      addresses:"
        echo "        - ${ip}/${cidr}"
        echo "      gateway4: ${GATEWAY:-}"
        echo "      nameservers:"
        echo "        addresses:"
        echo "          - 1.1.1.1"
        echo "          - 8.8.8.8"
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

generate_config() {
    info "$(t GENERATING "Generating configuration...")"
    
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
    echo " $(t CONFIRM "Configuration Summary")"
    echo "========================================"
    echo ""
    echo "  Hostname:   $HOSTNAME"
    echo "  SSH Port:   $SSH_PORT"
    echo "  Nomad:      $NOMAD_ROLE"
    echo "  Country:    ${COUNTRY^^}"
    echo "  Provider:   $MERCHANT"
    echo "  Network:    $NET_TYPE"
    if [[ "$TAILSCALE_ENABLE" == "yes" ]]; then
    echo "  Tailscale:  enabled"
    fi
    echo ""
    
    if [[ "$DD_MODE" == "yes" ]]; then
        echo "  Mode:       DD"
        echo "  Image:      $DD_IMAGE"
    else
        echo "  OS:         $OS $OS_VERSION"
        echo "  Mode:       Native"
    fi
    echo ""
}

download_and_execute() {
    local config_file="/tmp/user-data.$$"
    generate_config > "$config_file"
    
    header "$(t INSTALL_START "Starting Installation...")"
    
    info "Downloading reinstall script..."
    curl -fsSL https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh -o /tmp/reinstall.sh
    chmod +x /tmp/reinstall.sh
    
    info "Preparing cloud-init data..."
    local cloud_data="/tmp/cloud-data.$$"
    mkdir -p "$cloud_data"
    cp "$config_file" "$cloud_data/user-data"
    echo "instance-id: $HOSTNAME" > "$cloud_data/meta-data"
    
    info "Starting DD installation..."
    info "Image: $DD_IMAGE"
    info "This may take several minutes..."
    
    if [[ "$DD_MODE" == "yes" ]]; then
        /tmp/reinstall.sh dd --img "$DD_IMAGE" --cloud-data "$cloud_data" --force
    else
        /tmp/reinstall.sh "$OS" "$OS_VERSION" --cloud-data "$cloud_data" --force
    fi
    
    info "$(t DONE_DESC "Installation started. Check your provider console for progress.")"
}

main() {
    parse_args "$@"
    select_language
    
    detect_hardware
    detect_network
    detect_location
    
    prompt_country
    prompt_merchant
    prompt_ssh_key
    prompt_ssh_port
    prompt_nomad_role
    prompt_tailscale
    prompt_install_mode
    
    generate_hostname
    show_summary
    
    echo -n "$(t PROMPT_CONFIRM "Continue?") (Y/n): "
    read -r confirm
    confirm="${confirm:-Y}"
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "$(t CANCELLED "Cancelled")"
        exit 0
    fi
    
    if [[ "$EXECUTE_MODE" == "yes" ]]; then
        download_and_execute
    else
        generate_config
        echo ""
        echo "========================================"
        echo " $(t DONE "Configuration Complete")"
        echo "========================================"
    fi
}

main "$@"
