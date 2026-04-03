#!/bin/bash
# generate.sh - VPS è‡ªåŠ¨éƒ¨ç½²é…ç½®ç”Ÿæˆå™¨

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# åŠ è½½å‡½æ•°åº“
source "$SCRIPT_DIR/lib/output.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/network.sh"
source "$SCRIPT_DIR/config/region-codes.conf"

# é»˜è®¤é•œåƒ
DEFAULT_IMAGE="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.raw"

main() {
    header "VPS è‡ªåŠ¨éƒ¨ç½²é…ç½®ç”Ÿæˆå™¨"
    
    # ============ ç”¨æˆ·è¾“å…¥ ============
    section "ç”¨æˆ·é…ç½®"
    
    read -p "Merchant ID (oracle/aws/hetzner/vultr): " MERCHANT
    MERCHANT="${MERCHANT:-unknown}"
    
    read -p "åŒºåŸŸ (tokyo/frankfurt/newyork): " REGION
    REGION="${REGION:-unknown}"
    
    read -p "å›½å®¶ä»£ç  (jp/de/us): " COUNTRY
    COUNTRY="${COUNTRY:-us}"
    
    read -p "Nomad è§’è‰² [server]: " NOMAD_ROLE
    NOMAD_ROLE="${NOMAD_ROLE:-server}"
    
    read -p "SSH ç«¯å£ [22]: " SSH_PORT
    SSH_PORT="${SSH_PORT:-22}"
    
    read -p "SSH å…¬é’¥æ–‡ä»¶ [/root/.ssh/id_rsa.pub]: " SSH_KEY_FILE
    SSH_KEY_FILE="${SSH_KEY_FILE:-/root/.ssh/id_rsa.pub}"
    
    # ============ è‡ªåŠ¨æ£€æµ‹ ============
    header "ç¡¬ä»¶æ£€æµ‹"
    info "CPU æ ¸å¿ƒæ•°: $(detect_cpu_cores)"
    info "å†…å­˜: $(detect_memory_mb)MB"
    info "ç£ç›˜: $(detect_disk_gb)GB"
    
    header "ç½‘ç»œæ£€æµ‹"
    local eth=$(get_default_interface)
    info "ç½‘ç»œæŽ¥å£: $eth"
    
    # ç½‘ç»œç±»åž‹
    source <($SCRIPT_DIR/bin/network.sh)
    info "ç½‘ç»œç±»åž‹: $NET_TYPE"
    info "å…¬æœ‰ IPv4: ${PUBLIC_V4:-æ— }"
    info "ç§æœ‰ IPv4: ${PRIVATE_V4:-æ— }"
    
    # ============ ç”Ÿæˆä¸»æœºå ============
    local region_code="${REGION_CODES[$REGION]:-${REGION:0:3}}"
    region_code=$(echo "$region_code" | tr '[:upper:]' '[:lower:]')
    COUNTRY=$(echo "$COUNTRY" | tr '[:upper:]' '[:lower:]')
    local rand8=$(head /dev/urandom 2>/dev/null | tr -dc 'a-z0-9' | head -c 8)
    local HOSTNAME="${COUNTRY}-${region_code}-${NET_TYPE}-${MERCHANT}-${rand8}"
    
    # ============ SSH å¯†é’¥ ============
    section "SSH é…ç½®"
    if [[ -f "$SSH_KEY_FILE" ]]; then
        SSH_KEY=$(cat "$SSH_KEY_FILE")
        info "SSH å…¬é’¥: å·²åŠ è½½"
    else
        warn "SSH å…¬é’¥æ–‡ä»¶ä¸å­˜åœ¨: $SSH_KEY_FILE"
        read -p "æ‰‹åŠ¨è¾“å…¥ SSH å…¬é’¥: " SSH_KEY
    fi
    
    # ============ å¯†ç  ============
    section "ç”¨æˆ·å¯†ç "
    read -sp "è®¾ç½® deploy ç”¨æˆ·å¯†ç : " DEPLOY_PASS
    echo ""
    PASSWORD_HASH=$(openssl passwd -6 "$DEPLOY_PASS")
    
    # ============ ç¡®è®¤ ============
    header "é…ç½®ç¡®è®¤"
    cat << EOF
  ä¸»æœºå: $HOSTNAME
  Merchant: $MERCHANT
  åŒºåŸŸ: $REGION (${region_code})
  å›½å®¶: $COUNTRY
  ç½‘ç»œç±»åž‹: $NET_TYPE
  Nomad è§’è‰²: $NOMAD_ROLE
  SSH ç«¯å£: $SSH_PORT
  
  ç¡¬ä»¶:
    CPU: $(detect_cpu_cores) æ ¸å¿ƒ
    å†…å­˜: $(detect_memory_mb)MB
    ç£ç›˜: $(detect_disk_gb)GB
EOF
    
    echo ""
    read -p "ç¡®è®¤å¼€å§‹å®‰è£…? (yes/no): " confirm
    [[ "$confirm" != "yes" ]] && exit 0
    
    # ============ ç”Ÿæˆé…ç½® ============
    header "ç”Ÿæˆé…ç½®"
    
    # ç½‘ç»œé…ç½®
    if [[ -n "$PUBLIC_V4" ]]; then
        # é™æ€ IP
        NETWORK_CONFIG="      addresses:
        - $PUBLIC_V4
      gateway4: $GATEWAY"
    else
        # DHCP
        NETWORK_CONFIG="      dhcp4: true"
    fi
    
    # ç½‘ç»œé…ç½® (IPv6)
    if [[ -n "$PUBLIC_V6" ]]; then
        NETWORK_CONFIG="$NETWORK_CONFIG
      dhcp6: true
      accept-ra: true"
    fi
    
    # DNS
    NETWORK_CONFIG="$NETWORK_CONFIG
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
          - 223.5.5.5
        search: []"
    
    # Nomad é…ç½®
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
    
    # æž„å»º RUNCMD
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
    
    RUNCMD=$(cat << RUNCMD
  - systemctl restart sshd
  - apt update
  - DEBIAN_FRONTEND=noninteractive apt upgrade -y
  - timedatectl set-timezone UTC
$kernel_tuning
$nomad_runcmd
  - cloud-init clean --logs
RUNCMD
)
    
    # åˆ›å»º seed ç›®å½•
    mkdir -p /tmp/seed
    
    # ç”Ÿæˆ user-data
    cp "$SCRIPT_DIR/templates/user-data.tpl" /tmp/seed/user-data
    
    # æ›¿æ¢å˜é‡
    sed -i "s|{{ HOSTNAME }}|$HOSTNAME|g" /tmp/seed/user-data
    sed -i "s|{{ PASSWORD_HASH }}|$PASSWORD_HASH|g" /tmp/seed/user-data
    sed -i "s|{{ SSH_KEY }}|$SSH_KEY|g" /tmp/seed/user-data
    sed -i "s|{{ SSH_PORT }}|$SSH_PORT|g" /tmp/seed/user-data
    sed -i "s|{{ NOMAD_ROLE }}|$NOMAD_ROLE|g" /tmp/seed/user-data
    sed -i "s|{{ NETWORK_CONFIG }}|$NETWORK_CONFIG|g" /tmp/seed/user-data
    sed -i "s|{{ RUNCMD }}|$RUNCMD|g" /tmp/seed/user-data
    
    # ç”Ÿæˆ meta-data
    cp "$SCRIPT_DIR/templates/meta-data.tpl" /tmp/seed/meta-data
    sed -i "s|{{ HOSTNAME }}|$HOSTNAME|g" /tmp/seed/meta-data
    
    success "é…ç½®å·²ç”Ÿæˆåˆ° /tmp/seed/"
    
    # ============ å¼€å§‹å®‰è£… ============
    echo ""
    read -p "æ˜¯å¦å¼€å§‹ DD å®‰è£…? (yes/no): " start_install
    [[ "$start_install" != "yes" ]] && exit 0
    
    info "å¼€å§‹å®‰è£… Debian..."
    cd /tmp
    bash reinstall.sh dd --img "$DEFAULT_IMAGE" --cloud-data "file:///tmp/seed/"
}

main "$@"
