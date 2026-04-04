#!/bin/bash
# generate.sh - DeployX Main Wizard
# Usage: ./generate.sh [--lang LANG] [--dd]
# 
# This script guides users through VPS deployment configuration.
# It auto-detects hardware, network, and location, then generates
# cloud-init configurations for automated OS installation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
LIB_DIR="$SCRIPT_DIR/lib"
TPL_DIR="$SCRIPT_DIR/templates"

source "$LIB_DIR/output.sh"
source "$LIB_DIR/i18n.sh"

LANG="${LANG:-en}"
DD_MODE="${DD_MODE:-no}"

show_usage() {
    cat << EOF
Usage: $0 [options]
Options:
    --lang LANG    Language (en, zh) [default: en]
    --dd           Enable DD mode
    -h, --help     Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --lang) LANG="$2"; shift 2 ;;
            --dd) DD_MODE="yes"; shift ;;
            -h|--help) show_usage; exit 0 ;;
            *) shift ;;
        esac
    done
}

init_i18n() {
    i18n_load "$LANG" 2>/dev/null || {
        echo "[WARN] Failed to load translations, using defaults"
    }
}

t() {
    local key="$1"
    local default="${2:-}"
    if [[ "${I18N_LOADED:-0}" -eq 1 ]] && [[ -n "${T[$key]:-}" ]]; then
        echo "${T[$key]}"
    else
        echo "$default"
    fi
}

select_language() {
    echo ""
    echo "========================================"
    echo " DeployX - VPS Deployment Wizard"
    echo "========================================"
    echo ""
    echo "  1) English"
    echo "  2) Chinese / Zhongwen"
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
    info "Detecting hardware..."
    
    eval "$("$BIN_DIR/detect.sh")" 2>/dev/null || true
    CPU_CORES="${CPU_CORES:-$(nproc 2>/dev/null || echo 2)}"
    MEMORY_MB="${MEMORY_MB:-$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2/1024}' || echo 2048)}"
    DISK_GB="${DISK_GB:-$(df -h / 2>/dev/null | tail -1 | awk '{print $2}' || echo "50G")}"
}

detect_network() {
    info "Detecting network..."
    
    eval "$("$BIN_DIR/network.sh")" 2>/dev/null || true
    INTERFACE="${INTERFACE:-eth0}"
    NET_TYPE="${NET_TYPE:-v4}"
    PUBLIC_V4="${PUBLIC_V4:-}"
    PRIVATE_V4="${PRIVATE_V4:-}"
}

detect_location() {
    info "Detecting location..."
    
    eval "$("$BIN_DIR/location.sh")" 2>/dev/null || true
    COUNTRY="${COUNTRY:-us}"
    CITY="${CITY:-unknown}"
    REGION="${REGION:-unknown}"
}

prompt_country() {
    echo ""
    echo "--- $(t COUNTRY "Country") ---"
    echo "  Auto-detected: ${COUNTRY^^} (${CITY:-})"
    echo ""
    echo -n "Enter country code (e.g., us, jp, sg) [${COUNTRY}]: "
    read -r input
    COUNTRY="${input:-$COUNTRY}"
}

prompt_merchant() {
    echo ""
    echo "--- $(t MERCHANT "Provider/Merchant") ---"
    echo "  e.g., aws, digitalocean, vultr, hetzner"
    echo ""
    
    local valid=0
    while [[ $valid -eq 0 ]]; do
        echo -n "Provider name: "
        read -r MERCHANT
        
        if [[ -n "$MERCHANT" ]]; then
            valid=1
        else
            echo "Provider name is required"
        fi
    done
}

prompt_ssh_key() {
    echo ""
    echo "--- $(t SSH_KEY "SSH public key") ---"
    echo ""
    
    local valid=0
    while [[ $valid -eq 0 ]]; do
        echo -n "Paste SSH public key (ssh-rsa AAAA...): "
        read -r SSH_KEY
        
        if [[ -n "$SSH_KEY" ]]; then
            valid=1
        else
            echo "SSH key is required"
        fi
    done
}

prompt_ssh_port() {
    echo ""
    echo "--- $(t SSH_PORT "SSH port") ---"
    echo ""
    echo -n "SSH port [22]: "
    read -r input
    SSH_PORT="${input:-22}"
}

prompt_nomad_role() {
    echo ""
    echo "--- $(t NOMAD_ROLE "Nomad role") ---"
    echo "  1) None"
    echo "  2) Server"
    echo "  3) Client"
    echo "  4) Server + Client"
    echo ""
    
    local valid=0
    while [[ $valid -eq 0 ]]; do
        echo -n "Select role [4]: "
        read -r choice
        choice="${choice:-4}"
        
        case "$choice" in
            1) NOMAD_ROLE="none"; valid=1 ;;
            2) NOMAD_ROLE="server"; valid=1 ;;
            3) NOMAD_ROLE="client"; valid=1 ;;
            4) NOMAD_ROLE="server+client"; valid=1 ;;
            *) echo "Invalid selection" ;;
        esac
    done
}

prompt_tailscale() {
    echo ""
    echo "--- $(t TAILSCALE "Configure Tailscale?") ---"
    echo ""
    echo -n "Configure Tailscale? (y/N): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        TAILSCALE_ENABLE="yes"
        
        echo ""
        echo -n "Tailscale auth key (tskey-auth-xxx): "
        read -r TAILSCALE_KEY
    else
        TAILSCALE_ENABLE="no"
        TAILSCALE_KEY=""
    fi
}

prompt_install_mode() {
    echo ""
    echo "--- $(t INSTALL_MODE "Installation mode") ---"
    echo "  1) DD mode (full disk image)"
    echo "  2) Native mode (reinstall OS)"
    echo ""
    
    local valid=0
    while [[ $valid -eq 0 ]]; do
        echo -n "Select mode [2]: "
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
            *) echo "Invalid selection" ;;
        esac
    done
}

prompt_dd_image() {
    echo ""
    echo "--- $(t DD_IMAGE "DD image URL") ---"
    echo ""
    echo -n "Disk image URL: "
    read -r DD_IMAGE
}

prompt_os_select() {
    local OS_LIST=("Debian" "Ubuntu" "Alpine" "Rocky" "CentOS" "Fedora")
    
    echo ""
    echo "--- $(t OS_SELECT "Select operating system") ---"
    for i in "${!OS_LIST[@]}"; do
        echo "  $((i+1))) ${OS_LIST[$i]}"
    done
    echo ""
    
    local valid=0
    while [[ $valid -eq 0 ]]; do
        echo -n "Select OS [1]: "
        read -r choice
        choice="${choice:-1}"
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#OS_LIST[@]} ]]; then
            OS="${OS_LIST[$((choice-1))]}"
            OS_LOWER=$(echo "$OS" | tr '[:upper:]' '[:lower:]')
            valid=1
        else
            echo "Invalid selection"
        fi
    done
    
    prompt_os_version
}

prompt_os_version() {
    local versions=()
    
    case "$OS_LOWER" in
        debian)
            versions=("12" "11" "10")
            ;;
        ubuntu)
            versions=("24.04" "22.04" "20.04")
            ;;
        alpine)
            versions=("3.19" "3.18" "3.17")
            ;;
        rocky)
            versions=("9" "8")
            ;;
        centos)
            versions=("9" "8" "7")
            ;;
        fedora)
            versions=("40" "39" "38")
            ;;
    esac
    
    echo ""
    echo "--- $(t OS_VERSION "Select version") ---"
    for i in "${!versions[@]}"; do
        echo "  $((i+1))) ${versions[$i]}"
    done
    echo ""
    
    local valid=0
    while [[ $valid -eq 0 ]]; do
        echo -n "Select version [1]: "
        read -r choice
        choice="${choice:-1}"
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#versions[@]} ]]; then
            OS_VERSION="${versions[$((choice-1))]}"
            valid=1
        else
            echo "Invalid selection"
        fi
    done
}

generate_hostname() {
    local suffix
    suffix=$(head /dev/urandom 2>/dev/null | tr -dc 'a-z0-9' | head -c 8 || echo "$(date +%s | md5sum | head -c 8)")
    HOSTNAME="$("$BIN_DIR/hostname.sh" -c "$COUNTRY" -r "$REGION" -n "$NET_TYPE" -m "$MERCHANT" -s "$suffix")"
    HOSTNAME="${HOSTNAME#*=}"
}

generate_network_config() {
    local net_config=""
    
    if [[ -n "$PUBLIC_V4" ]]; then
        local ip="${PUBLIC_V4%%/*}"
        local cidr="${PUBLIC_V4#*/}"
        cidr="${cidr:-24}"
        local gateway="${GATEWAY:-}"
        
        net_config="      addresses:
        - ${ip}/${cidr}
      gateway4: ${gateway}
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8"
    elif [[ -n "$PRIVATE_V4" ]]; then
        net_config="      dhcp4: true"
    else
        net_config="      dhcp4: true"
    fi
    
    echo "$net_config"
}

generate_runcmd() {
    local runcmd=""
    
    runcmd="  - echo 'Host *' > /etc/ssh/sshd_config.d/disable.conf
  - echo '    StrictHostKeyChecking no' >> /etc/ssh/sshd_config.d/disable.conf
  - systemctl restart sshd"
    
    if [[ "$NOMAD_ROLE" != "none" ]]; then
        runcmd="$runcmd"$'\n'"$("$BIN_DIR/nomad.sh" -r "$NOMAD_ROLE" -n "$HOSTNAME" --runcmd 2>/dev/null || true)"
    fi
    
    if [[ "$TAILSCALE_ENABLE" == "yes" ]] && [[ -n "$TAILSCALE_KEY" ]]; then
        runcmd="$runcmd"$'\n'"$("$BIN_DIR/tailscale.sh" -k "$TAILSCALE_KEY" -o runcmd 2>/dev/null || true)"
    fi
    
    echo "$runcmd"
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

generate_config() {
    info "Generating configuration..."
    
    local network_config
    network_config=$(generate_network_config)
    
    local runcmd
    runcmd=$(generate_runcmd)
    
    local user_data
    user_data=$("$BIN_DIR/render.sh" \
        -t "$TPL_DIR/user-data.tpl" \
        -v "HOSTNAME=$HOSTNAME" \
        -v "SSH_KEY=$SSH_KEY" \
        -v "SSH_PORT=$SSH_PORT" \
        -v "PASSWORD_HASH=" \
        -v "NETWORK_CONFIG=$network_config" \
        -v "RUNCMD=$runcmd" \
        -v "NOMAD_ROLE=$NOMAD_ROLE")
    
    local meta_data
    meta_data=$("$BIN_DIR/render.sh" \
        -t "$TPL_DIR/meta-data.tpl" \
        -v "HOSTNAME=$HOSTNAME")
    
    echo "$user_data"
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
    
    echo -n "Continue with installation? (Y/n): "
    read -r confirm
    confirm="${confirm:-Y}"
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    
    local config
    config=$(generate_config)
    
    echo ""
    echo "========================================"
    echo " Configuration Complete"
    echo "========================================"
    echo ""
    echo "$config"
}

main "$@"
