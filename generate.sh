#!/bin/bash
# generate.sh - VPS Auto Deployment Tool

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/lib/output.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/network.sh"
source "$SCRIPT_DIR/lib/i18n.sh"
source "$SCRIPT_DIR/config/region-codes.conf"

i18n_init

DEFAULT_IMAGE="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.raw"

select_language() {
    echo ""
    echo "Select language / 选择语言:"
    echo "  1) English"
    echo "  2) 中文"
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

main() {
    select_language
    
    header "$(_ HEADER_MAIN)"
    
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
    
    local region_code="${REGION_CODES[$REGION]:-${REGION:0:3}}"
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
  $(_ LABEL_MERCHANT): $MERCHANT
  $(_ LABEL_REGION): $REGION (${region_code})
  $(_ LABEL_COUNTRY): $COUNTRY
  $(_ LABEL_NET_TYPE): $(get_net_type_label)
  $(_ LABEL_NOMAD_ROLE): $NOMAD_ROLE
  $(_ LABEL_SSH_PORT): $SSH_PORT
  
  $(_ LABEL_HARDWARE):
    $(_ LABEL_CPU_CORES): $(detect_cpu_cores)
    $(_ LABEL_MEMORY_MB): $(detect_memory_mb)MB
    $(_ LABEL_DISK_GB): $(detect_disk_gb)GB
EOF
    
    echo ""
    read -p "$(_ PROMPT_CONFIRM)" confirm
    [[ "$confirm" != "$(_ YES)" ]] && exit 0
    
    header "$(_ SECTION_GENERATING)"
    
    if [[ -n "$PUBLIC_V4" ]]; then
        NETWORK_CONFIG="      addresses:
        - $PUBLIC_V4
      gateway4: $GATEWAY"
    else
        NETWORK_CONFIG="      dhcp4: true"
    fi
    
    if [[ -n "$PUBLIC_V6" ]]; then
        NETWORK_CONFIG="$NETWORK_CONFIG
      dhcp6: true
      accept-ra: true"
    fi
    
    NETWORK_CONFIG="$NETWORK_CONFIG
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
          - 223.5.5.5
        search: []"
    
    local nomad_runcmd=""
    if [[ "$NOMAD_ROLE" == "server" ]]; then
        nomad_runcmd=$(cat << 'NOMADCMD'
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
    name = "HOSTNAME_PLACEHOLDER"
    datacenter = "dc1"
    region = "global"
    data_dir = "/opt/nomad/data"
    bind_addr = "0.0.0.0"
    ports { http = 4646 rpc = 4647 serf = 4648 }
    server { enabled = true bootstrap_expect = 1 }
    client { enabled = false }
    telemetry { prometheus_metrics = true }
    NOMADCFG
    sed -i "s/HOSTNAME_PLACEHOLDER/HOSTNAME_VAR/g" /etc/nomad.d/server.hcl
    sed -i "s/HOSTNAME_VAR/$HOSTNAME/g" /etc/nomad.d/server.hcl
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
    systemctl daemon-reload
    systemctl enable nomad
    systemctl start nomad
NOMADCMD
    )
    fi
    
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
    
    RUNCMD=$(cat << 'RUNCMD'
  - systemctl restart sshd
  - apt update
  - DEBIAN_FRONTEND=noninteractive apt upgrade -y
  - timedatectl set-timezone UTC
$kernel_tuning
$nomad_runcmd
  - cloud-init clean --logs
RUNCMD
)
    
    mkdir -p /tmp/seed
    
    cp "$SCRIPT_DIR/templates/user-data.tpl" /tmp/seed/user-data
    
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
    bash reinstall.sh dd --img "$DEFAULT_IMAGE" --cloud-data "file:///tmp/seed/"
}

main "$@"
