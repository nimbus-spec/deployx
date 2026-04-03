#!/bin/bash
# generate.sh - VPS Auto Deployment Tool

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/lib/output.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/network.sh"
source "$SCRIPT_DIR/lib/i18n.sh"
source "$SCRIPT_DIR/config/region-codes.conf"

i18n_init

declare -A OS_OPTIONS
OS_OPTIONS=(
    ["debian"]="Debian (12/13)"
    ["ubuntu"]="Ubuntu (20.04/22.04/24.04)"
    ["alpine"]="Alpine Linux (3.20/3.21)"
    ["centos"]="CentOS Stream (9/10)"
    ["rocky"]="Rocky Linux (8/9/10)"
    ["almalinux"]="AlmaLinux (8/9/10)"
    ["fedora"]="Fedora (42/43)"
    ["dd"]="Custom DD Image"
)

declare -A OS_VERSIONS
OS_VERSIONS=(
    ["debian"]="12"
    ["ubuntu"]="24.04"
    ["alpine"]="3.21"
    ["centos"]="9"
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
        2|"zh")
            i18n_load "zh"
            ;;
        *)
            i18n_load "en"
            ;;
    esac
}

get_net_type_label() {
    case "$NET_TYPE" in
        v4) _ "NET_TYPE_V4" "IPv4" ;;
        v6) _ "NET_TYPE_V6" "IPv6" ;;
        dual) _ "NET_TYPE_DUAL" "Dual" ;;
        nat) _ "NET_TYPE_NAT" "NAT" ;;
        *) _ "NET_TYPE_UNKNOWN" "Unknown" ;;
    esac
}

select_os() {
    echo ""
    echo "$(_ SECTION_OS_SELECTION)"
    echo ""
    local i=1
    local keys=()
    for key in "${!OS_OPTIONS[@]}"; do
        echo "  $i) ${OS_OPTIONS[$key]}"
        keys+=("$key")
        ((i++))
    done
    echo ""
    read -p "$(_ PROMPT_OS_SELECTION)" choice
    choice="${choice:-1}"
    
    local index=$((choice - 1))
    if [[ $index -ge 0 ]] && [[ $index -lt ${#keys[@]} ]]; then
        SELECTED_OS="${keys[$index]}"
    else
        SELECTED_OS="debian"
    fi
}

select_os_version() {
    [[ "$SELECTED_OS" == "dd" ]] && return
    
    echo ""
    local default_ver="${OS_VERSIONS[$SELECTED_OS]}"
    read -p "$(echo "$(_ PROMPT_OS_VERSION)" | sed "s/{{version}}/$default_ver/")" OS_VERSION
    OS_VERSION="${OS_VERSION:-$default_ver}"
}

select_install_mode() {
    echo ""
    echo "$(_ SECTION_INSTALL_MODE)"
    echo ""
    echo "  1) $(_ INSTALL_MODE_NATIVE)"
    echo "  2) $(_ INSTALL_MODE_DD)"
    echo ""
    read -p "$(_ PROMPT_INSTALL_MODE)" choice
    choice="${choice:-1}"
    
    [[ "$choice" == "2" ]] && INSTALL_MODE="dd" || INSTALL_MODE="native"
}

get_os_label() {
    [[ "$SELECTED_OS" == "dd" ]] && _ "LABEL_CUSTOM_DD" || echo "${OS_OPTIONS[$SELECTED_OS]}"
}

main() {
    select_language
    
    header "$(_ HEADER_MAIN)"
    
    section "$(_ SECTION_OS_SELECTION)"
    select_os
    select_os_version
    
    if [[ "$SELECTED_OS" == "dd" ]]; then
        section "$(_ SECTION_DD_IMAGE)"
        read -p "$(_ PROMPT_DD_IMAGE_URL)" DD_IMAGE_URL
        [[ -z "$DD_IMAGE_URL" ]] && { error "$(_ ERROR_DD_IMAGE_REQUIRED)"; exit 1; }
        INSTALL_MODE="dd"
    else
        select_install_mode
    fi
    
    section "$(_ SECTION_CONFIG)"
    
    read -p "$(_ PROMPT_MERCHANT)" MERCHANT
    MERCHANT="${MERCHANT:-unknown}"
    
    read -p "$(_ PROMPT_REGION)" REGION
    REGION="${REGION:-unknown}"
    
    read -p "$(_ PROMPT_COUNTRY)" COUNTRY
    COUNTRY="${COUNTRY:-us}"
    
    read -p "$(_ PROMPT_NOMAD_ROLE)" NOMAD_ROLE
    NOMAD_ROLE="${NOMAD_ROLE:-server}"
    
    read -p "$(_ PROMPT_SSH_PORT)" SSH_PORT
    SSH_PORT="${SSH_PORT:-22}"
    
    read -p "$(_ PROMPT_SSH_KEY)" SSH_KEY_FILE
    SSH_KEY_FILE="${SSH_KEY_FILE:-/root/.ssh/id_rsa.pub}"
    
    section "$(_ SECTION_TAILSCALE)"
    read -p "$(_ PROMPT_TAILSCALE_ENABLED)" TAILSCALE_ENABLED
    TAILSCALE_ENABLED="${TAILSCALE_ENABLED:-no}"
    
    if [[ "$TAILSCALE_ENABLED" =~ ^(yes|y)$ ]]; then
        read -p "$(_ PROMPT_TAILSCALE_AUTHKEY)" TAILSCALE_AUTH_KEY
        TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
        read -p "$(_ PROMPT_TAILSCALE_ACCEPT_ROUTES)" TAILSCALE_ACCEPT_ROUTES
        TAILSCALE_ACCEPT_ROUTES="${TAILSCALE_ACCEPT_ROUTES:-no}"
    else
        TAILSCALE_AUTH_KEY=""
        TAILSCALE_ACCEPT_ROUTES="no"
    fi
    
    header "$(_ SECTION_HARDWARE)"
    info "$(_ INFO_CPU): $(detect_cpu_cores)"
    info "$(_ INFO_MEMORY): $(detect_memory_mb)MB"
    info "$(_ INFO_DISK): $(detect_disk_gb)GB"
    
    header "$(_ SECTION_NETWORK)"
    local eth=$(get_default_interface)
    info "$(_ INFO_NET_IFACE): $eth"
    
    source <($SCRIPT_DIR/bin/network.sh)
    info "$(_ INFO_NET_TYPE): $(get_net_type_label)"
    info "$(_ INFO_PUB_IPV4): ${PUBLIC_V4:-$(_ STATUS_NONE)}"
    info "$(_ INFO_PRIV_IPV4): ${PRIVATE_V4:-$(_ STATUS_NONE)}"
    
    local region_code="${REGION_CODES[$REGION]:-$(echo "$REGION" | cut -c1-3)}"
    region_code=$(echo "$region_code" | tr '[:upper:]' '[:lower:]')
    COUNTRY=$(echo "$COUNTRY" | tr '[:upper:]' '[:lower:]')
    local rand8=$(head /dev/urandom 2>/dev/null | tr -dc 'a-z0-9' | head -c 8)
    local HOSTNAME="${COUNTRY}-${region_code}-${NET_TYPE}-${MERCHANT}-${rand8}"
    
    section "$(_ SECTION_SSH)"
    if [[ -f "$SSH_KEY_FILE" ]]; then
        SSH_KEY=$(cat "$SSH_KEY_FILE")
        info "$(_ INFO_SSH_KEY_LOADED)"
    else
        warn "$(_ INFO_SSH_KEY_MISSING): $SSH_KEY_FILE"
        read -p "$(_ INFO_SSH_KEY_MANUAL): " SSH_KEY
    fi
    
    section "$(_ SECTION_PASSWORD)"
    read -sp "$(_ PROMPT_PASSWORD)" DEPLOY_PASS
    echo ""
    PASSWORD_HASH=$(openssl passwd -6 "$DEPLOY_PASS")
    
    header "$(_ SECTION_CONFIRM)"
    cat << EOF
  $(_ LABEL_HOSTNAME): $HOSTNAME
  $(_ LABEL_OS): $(get_os_label)
  $(_ LABEL_INSTALL_MODE): $(if [[ "$INSTALL_MODE" == "dd" ]]; then _ "INSTALL_MODE_DD"; else _ "INSTALL_MODE_NATIVE"; fi)
  $(_ LABEL_MERCHANT): $MERCHANT
  $(_ LABEL_REGION): $REGION (${region_code})
  $(_ LABEL_COUNTRY): $COUNTRY
  $(_ LABEL_NET_TYPE): $(get_net_type_label)
  $(_ LABEL_NOMAD_ROLE): $NOMAD_ROLE
  $(_ LABEL_SSH_PORT): $SSH_PORT
  $(_ LABEL_TAILSCALE): $(if [[ "$TAILSCALE_ENABLED" =~ ^(yes|y)$ ]]; then _ "STATUS_ENABLED"; else _ "STATUS_DISABLED"; fi)
  
  $(_ LABEL_HARDWARE):
    $(_ LABEL_CPU_CORES): $(detect_cpu_cores)
    $(_ LABEL_MEMORY_MB): $(detect_memory_mb)MB
    $(_ LABEL_DISK_GB): $(detect_disk_gb)GB
EOF
    
    [[ "$SELECTED_OS" == "dd" ]] && echo "  $(_ LABEL_DD_IMAGE): $DD_IMAGE_URL"
    
    echo ""
    read -p "$(_ PROMPT_CONFIRM)" confirm
    [[ "$confirm" != "$(_ YES)" ]] && exit 0
    
    header "$(_ SECTION_GENERATING)"
    
    mkdir -p /tmp/seed
    
    if [[ "$INSTALL_MODE" == "dd" ]]; then
        cp "$SCRIPT_DIR/templates/user-data.tpl" /tmp/seed/user-data
        
        if [[ -n "$PUBLIC_V4" ]]; then
            NETWORK_CONFIG="      addresses:
        - $PUBLIC_V4
      gateway4: $GATEWAY"
        else
            NETWORK_CONFIG="      dhcp4: true"
        fi
        
        [[ -n "$PUBLIC_V6" ]] && NETWORK_CONFIG="$NETWORK_CONFIG
      dhcp6: true
      accept-ra: true"
        
        NETWORK_CONFIG="$NETWORK_CONFIG
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
          - 223.5.5.5
        search: []"
        
        local kernel_tuning=$(cat << 'KERNEL'
  - |
    cat > /etc/sysctl.d/99-tuning.conf << 'SYSCTL'
    net.core.default_qdisc = fq
    net.ipv4.tcp_congestion_control = bbr
    net.ipv4.tcp_fastopen = 3
    net.core.somaxconn = 65535
    net.ipv4.tcp_max_syn_backlog = 65535
    net.ipv4.tcp_syncookies = 1
    fs.file-max = 65535
    SYSCTL
    sysctl -p /etc/sysctl.d/99-tuning.conf 2>/dev/null || true
    modprobe tcp_bbr 2>/dev/null || true
KERNEL
)
        
        local nomad_runcmd=""
        [[ "$NOMAD_ROLE" == "server" ]] && nomad_runcmd=$(cat << 'NOMADCMD'
  - |
    NOMAD_VERSION=$(curl -fsSL "https://api.github.com/repos/hashicorp/nomad/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/' || echo "1.7.6")
    curl -fsSL "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip" -o /tmp/nomad.zip
    unzip -o /tmp/nomad.zip -d /usr/local/bin/
    chmod +x /usr/local/bin/nomad
    rm /tmp/nomad.zip
    useradd -r -d /var/lib/nomad -s /bin/false nomad 2>/dev/null || true
    mkdir -p /var/lib/nomad /etc/nomad.d /opt/nomad/data
    chown -R nomad:nomad /var/lib/nomad /opt/nomad
    cat > /etc/nomad.d/server.hcl << 'NOMADCFG'
    name = "NOMAD_HOSTNAME"
    datacenter = "dc1"
    region = "global"
    data_dir = "/opt/nomad/data"
    bind_addr = "0.0.0.0"
    ports { http = 4646 rpc = 4647 serf = 4648 }
    server { enabled = true bootstrap_expect = 1 }
    client { enabled = false }
    telemetry { prometheus_metrics = true }
    NOMADCFG
    sed -i "s/NOMAD_HOSTNAME/$HOSTNAME/g" /etc/nomad.d/server.hcl
    cat > /etc/systemd/system/nomad.service << 'SYSTEMD'
    [Unit]
    Description=Nomad
    After=network-online.target
    [Service]
    ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d/
    Restart=always
    [Install]
    WantedBy=multi-user.target
    SYSTEMD
    systemctl daemon-reload && systemctl enable nomad && systemctl start nomad
NOMADCMD
        )
        
        local tailscale_runcmd=""
        if [[ "$TAILSCALE_ENABLED" =~ ^(yes|y)$ ]] && [[ -n "$TAILSCALE_AUTH_KEY" ]]; then
            local accept_flag=""
            [[ "$TAILSCALE_ACCEPT_ROUTES" =~ ^(yes|y)$ ]] && accept_flag="--accept-routes"
            tailscale_runcmd="  - |
    curl -fsSL https://tailscale.com/install.sh | sh
    tailscale up --authkey=${TAILSCALE_AUTH_KEY} ${accept_flag}
"
        fi
        
        local RUNCMD="  - systemctl restart sshd
  - apt update
  - DEBIAN_FRONTEND=noninteractive apt upgrade -y
  - timedatectl set-timezone UTC
${kernel_tuning}
${nomad_runcmd}
${tailscale_runcmd}
  - cloud-init clean --logs"
        
        sed -i "s|{{ HOSTNAME }}|$HOSTNAME|g" /tmp/seed/user-data
        sed -i "s|{{ PASSWORD_HASH }}|$PASSWORD_HASH|g" /tmp/seed/user-data
        sed -i "s|{{ SSH_KEY }}|$SSH_KEY|g" /tmp/seed/user-data
        sed -i "s|{{ SSH_PORT }}|$SSH_PORT|g" /tmp/seed/user-data
        sed -i "s|{{ NOMAD_ROLE }}|$NOMAD_ROLE|g" /tmp/seed/user-data
        sed -i "s|{{ NETWORK_CONFIG }}|$NETWORK_CONFIG|g" /tmp/seed/user-data
        sed -i "s|{{ RUNCMD }}|$RUNCMD|g" /tmp/seed/user-data
        
        cp "$SCRIPT_DIR/templates/meta-data.tpl" /tmp/seed/meta-data
        sed -i "s|{{ HOSTNAME }}|$HOSTNAME|g" /tmp/seed/meta-data
        
        success "$(_ INFO_CONFIG_GENERATED)"
        
        echo ""
        read -p "$(_ PROMPT_START_INSTALL)" start_install
        [[ "$start_install" != "$(_ YES)" ]] && exit 0
        
        info "$(_ INFO_INSTALL_START)"
        cd /tmp
        
        curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
        chmod +x reinstall.sh
        bash reinstall.sh dd --img "$DD_IMAGE_URL" --cloud-data "file:///tmp/seed/"
        
    else
        cp "$SCRIPT_DIR/templates/meta-data.tpl" /tmp/seed/meta-data
        sed -i "s|{{ HOSTNAME }}|$HOSTNAME|g" /tmp/seed/meta-data
        
        success "$(_ INFO_CONFIG_GENERATED)"
        
        echo ""
        read -p "$(_ PROMPT_START_INSTALL)" start_install
        [[ "$start_install" != "$(_ YES)" ]] && exit 0
        
        info "$(_ INFO_INSTALL_START)"
        cd /tmp
        
        curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
        chmod +x reinstall.sh
        
        local ssh_arg="--ssh-key '$SSH_KEY'"
        [[ -z "$SSH_KEY" ]] && ssh_arg="--password '$DEPLOY_PASS'"
        
        bash reinstall.sh "$SELECTED_OS" "$OS_VERSION" \
            --hostname "$HOSTNAME" \
            --ssh-port "$SSH_PORT" \
            $ssh_arg \
            --cloud-data "file:///tmp/seed/"
    fi
}

main "$@"
