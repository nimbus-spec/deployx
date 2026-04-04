#!/bin/bash
# bin/nomad.sh - Nomad configuration generator
# Usage: ./bin/nomad.sh -r ROLE -n HOSTNAME [-o OUTPUT_DIR] [--runcmd]
# Output: Nomad configuration files

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NOMAD_VERSION="${NOMAD_VERSION:-1.7.6}"

usage() {
    cat << EOF
Usage: $0 [options]
Options:
    -r ROLE        Role: server, client, server+client
    -n HOSTNAME   Nomad hostname
    -o DIR        Output directory (default: /etc/nomad.d)
    --runcmd      Output runcmd format
    -h            Show this help
EOF
}

ROLE=""
HOSTNAME=""
OUTPUT_DIR="/etc/nomad.d"
RUNCMD_MODE="no"

for arg in "$@"; do
    case "$arg" in
        --runcmd) RUNCMD_MODE="yes" ;;
        -r|-n|-o) shift ;;
    esac
done

while getopts "r:n:o:h" opt; do
    case $opt in
        r) ROLE="$OPTARG" ;;
        n) HOSTNAME="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) usage; exit 0 ;;
    esac
done

[[ -z "$ROLE" ]] && { echo "Error: -r ROLE required"; exit 1; }
[[ -z "$HOSTNAME" ]] && { echo "Error: -n HOSTNAME required"; exit 1; }

output_runcmd() {
    echo "  - |"
    echo "    NOMAD_VERSION=\$(curl -fsSL https://api.github.com/repos/hashicorp/nomad/releases/latest 2>/dev/null | grep tag_name | sed -E 's/.*v(.+).*/\\1/' || echo $NOMAD_VERSION)"
    echo "    curl -fsSL https://releases.hashicorp.com/nomad/\${NOMAD_VERSION}/nomad_\${NOMAD_VERSION}_linux_amd64.zip -o /tmp/nomad.zip"
    echo "    unzip -o /tmp/nomad.zip -d /usr/local/bin/"
    echo "    chmod +x /usr/local/bin/nomad"
    echo "    rm /tmp/nomad.zip"
    echo "    useradd -r -d /var/lib/nomad -s /bin/false nomad 2>/dev/null || true"
    echo "    mkdir -p /var/lib/nomad /etc/nomad.d /opt/nomad/data"
    echo "    chown -R nomad:nomad /var/lib/nomad /opt/nomad"
    echo ""
    echo "  - |"
    echo "    cat > /etc/nomad.d/nomad.hcl << 'NOMADCFG'"
    echo "name = \"$HOSTNAME\""
    echo "datacenter = \"dc1\""
    echo "region = \"global\""
    echo "data_dir = \"/opt/nomad/data\""
    echo "bind_addr = \"0.0.0.0\""
    echo "ports { http = 4646 rpc = 4647 serf = 4648 }"
    
    if [[ "$ROLE" == "server" ]] || [[ "$ROLE" == "server+client" ]]; then
        echo ""
        echo "server {"
        echo "  enabled = true"
        echo "  bootstrap_expect = 1"
        echo "}"
    fi
    
    if [[ "$ROLE" == "client" ]] || [[ "$ROLE" == "server+client" ]]; then
        echo ""
        echo "client {"
        echo "  enabled = true"
        echo "  servers = [\"127.0.0.1:4647\"]"
        echo "}"
    fi
    
    echo ""
    echo "telemetry {"
    echo "  prometheus_metrics = true"
    echo "}"
    echo "    NOMADCFG"
    echo ""
    echo "  - |"
    echo "    cat > /etc/systemd/system/nomad.service << 'NOMADSVC'"
    echo "[Unit]"
    echo "Description=Nomad"
    echo "After=network-online.target"
    echo "Wants=network-online.target"
    echo ""
    echo "[Service]"
    echo "ExecReload=/bin/kill -HUP \$MAINPID"
    echo "ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d/"
    echo "KillMode=process"
    echo "KillSignal=SIGINT"
    echo "LimitNOFILE=65536"
    echo "Restart=on-failure"
    echo "RestartSec=2"
    echo "TasksMax=infinity"
    echo ""
    echo "[Install]"
    echo "WantedBy=multi-user.target"
    echo "    NOMADSVC"
    echo ""
    echo "  - systemctl daemon-reload"
    echo "  - systemctl enable nomad"
    echo "  - systemctl start nomad"
}

if [[ "$RUNCMD_MODE" == "yes" ]]; then
    output_runcmd
fi
