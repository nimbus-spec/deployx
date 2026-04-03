#!/bin/bash
# generate.sh - VPS 自动部署配置生成器

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/lib/output.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/network.sh"
source "$SCRIPT_DIR/config/region-codes.conf"

DEFAULT_IMAGE="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.raw"

main() {
    header "VPS 自动部署配置生成器"
    
    section "用户配置"
    
    read -p "Merchant ID (oracle/aws/hetzner/vultr): " MERCHANT
    MERCHANT="${MERCHANT:-unknown}"
    
    read -p "区域 (tokyo/frankfurt/newyork): " REGION
    REGION="${REGION:-unknown}"
    
    read -p "国家代码 (jp/de/us): " COUNTRY
    COUNTRY="${COUNTRY:-us}"
    
    read -p "Nomad 角色 [server]: " NOMAD_ROLE
    NOMAD_ROLE="${NOMAD_ROLE:-server}"
    
    read -p "SSH 端口 [22]: " SSH_PORT
    SSH_PORT="${SSH_PORT:-22}"
    
    read -p "SSH 公钥文件 [/root/.ssh/id_rsa.pub]: " SSH_KEY_FILE
    SSH_KEY_FILE="${SSH_KEY_FILE:-/root/.ssh/id_rsa.pub}"
    
    header "硬件检测"
    info "CPU 核心数: $(detect_cpu_cores)"
    info "内存: $(detect_memory_mb)MB"
    info "磁盘: $(detect_disk_gb)GB"
    
    header "网络检测"
    local eth=$(get_default_interface)
    info "网络接口: $eth"
    
    source <($SCRIPT_DIR/bin/network.sh)
    info "网络类型: $NET_TYPE"
    info "公有 IPv4: ${PUBLIC_V4:-无}"
    info "私有 IPv4: ${PRIVATE_V4:-无}"
    
    local region_code="${REGION_CODES[$REGION]:-${REGION:0:3}}"
    region_code=$(echo "$region_code" | tr '[:upper:]' '[:lower:]')
    COUNTRY=$(echo "$COUNTRY" | tr '[:upper:]' '[:lower:]')
    local rand8=$(head /dev/urandom 2>/dev/null | tr -dc 'a-z0-9' | head -c 8)
    local HOSTNAME="${COUNTRY}-${region_code}-${NET_TYPE}-${MERCHANT}-${rand8}"
    
    section "SSH 配置"
    if [[ -f "$SSH_KEY_FILE" ]]; then
        SSH_KEY=$(cat "$SSH_KEY_FILE")
        info "SSH 公钥: 已加载"
    else
        warn "SSH 公钥文件不存在: $SSH_KEY_FILE"
        read -p "手动输入 SSH 公钥: " SSH_KEY
    fi
    
    section "用户密码"
    read -sp "设置 deploy 用户密码: " DEPLOY_PASS
    echo ""
    PASSWORD_HASH=$(openssl passwd -6 "$DEPLOY_PASS")
    
    header "配置确认"
    cat << 'EOF'
  主机名: $HOSTNAME
  Merchant: $MERCHANT
  区域: $REGION (${region_code})
  国家: $COUNTRY
  网络类型: $NET_TYPE
  Nomad 角色: $NOMAD_ROLE
  SSH 端口: $SSH_PORT
  
  硬件:
    CPU: $(detect_cpu_cores) 核心
    内存: $(detect_memory_mb)MB
    磁盘: $(detect_disk_gb)GB
EOF
    
    echo ""
    read -p "确认开始安装? (yes/no): " confirm
    [[ "$confirm" != "yes" ]] && exit 0
    
    header "生成配置"
    
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
    
    success "配置已生成到 /tmp/seed/"
    
    echo ""
    read -p "是否开始 DD 安装? (yes/no): " start_install
    [[ "$start_install" != "yes" ]] && exit 0
    
    info "开始安装 Debian..."
    cd /tmp
    bash reinstall.sh dd --img "$DEFAULT_IMAGE" --cloud-data "file:///tmp/seed/"
}

main "$@"
