#!/bin/bash
# bin/nomad.sh - Nomad configuration generator
# Usage: ./bin/nomad.sh -r ROLE -n HOSTNAME [-o OUTPUT_DIR]
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
    -h            Show this help
EOF
}

ROLE=""
HOSTNAME=""
OUTPUT_DIR="/etc/nomad.d"
RUNCMD_MODE="no"

# Check for --runcmd first (before getopts)
for arg in "$@"; do
    if [[ "$arg" == "--runcmd" ]]; then
        RUNCMD_MODE="yes"
        break
    fi
done

# Filter out --runcmd for getopts
ARGS=()
for arg in "$@"; do
    [[ "$arg" != "--runcmd" ]] && ARGS+=("$arg")
done

while getopts "r:n:o:h" opt; do
    case $opt in
        r) ROLE="$OPTARG" ;;
        n) HOSTNAME="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) ;;
    esac
done

[[ -z "$ROLE" ]] && { echo "Error: -r ROLE required"; exit 1; }
[[ -z "$HOSTNAME" ]] && { echo "Error: -n HOSTNAME required"; exit 1; }

generate_install_cmd() {
    cat << 'INSTALL'
  - |
    NOMAD_VERSION=$(curl -fsSL "https://api.github.com/repos/hashicorp/nomad/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/' || echo "VERSION_PLACEHOLDER")
    curl -fsSL "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip" -o /tmp/nomad.zip
    unzip -o /tmp/nomad.zip -d /usr/local/bin/
    chmod +x /usr/local/bin/nomad
    rm /tmp/nomad.zip
    useradd -r -d /var/lib/nomad -s /bin/false nomad 2>/dev/null || true
    mkdir -p /var/lib/nomad /etc/nomad.d /opt/nomad/data
    chown -R nomad:nomad /var/lib/nomad /opt/nomad
INSTALL
}

generate_server_config() {
    printf 'name = "HOSTNAME_PLACEHOLDER"\n'
    printf 'datacenter = "dc1"\n'
    printf 'region = "global"\n'
    printf 'data_dir = "/opt/nomad/data"\n'
    printf 'bind_addr = "0.0.0.0"\n'
    printf 'ports { http = 4646 rpc = 4647 serf = 4648 }\n'
    
    if [[ "$ROLE" == "server" ]] || [[ "$ROLE" == "server+client" ]]; then
        printf '\nserver {\n'
        printf '  enabled = true\n'
        printf '  bootstrap_expect = 1\n'
        printf '}\n'
    fi
    
    if [[ "$ROLE" == "client" ]] || [[ "$ROLE" == "server+client" ]]; then
        printf '\nclient {\n'
        printf '  enabled = true\n'
        printf '  servers = ["127.0.0.1:4647"]\n'
        printf '}\n'
    fi
    
    printf '\ntelemetry {\n'
    printf '  prometheus_metrics = true\n'
    printf '}\n'
}

generate_systemd_service() {
    cat << 'SYSTEMD'
[Unit]
Description=Nomad
After=network-online.target
Wants=network-online.target

[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d/
KillMode=process
KillSignal=SIGINT
LimitNOFILE=65536
Restart=on-failure
RestartSec=2
TasksMax=infinity

[Install]
WantedBy=multi-user.target
SYSTEMD
}

output_nomad_config() {
    if [[ "$1" == "--runcmd" ]]; then
        generate_install_cmd | sed "s/VERSION_PLACEHOLDER/$NOMAD_VERSION/"
        echo ""
        echo "  - |"
        echo "    cat > /etc/nomad.d/nomad.hcl << 'NOMADCFG'"
        generate_server_config | sed "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/g"
        echo "    NOMADCFG"
        echo ""
        echo "  - |"
        echo "    cat > /etc/systemd/system/nomad.service << 'NOMADSVC'"
        generate_systemd_service
        echo "    NOMADSVC"
        echo ""
        echo "  - systemctl daemon-reload"
        echo "  - systemctl enable nomad"
        echo "  - systemctl start nomad"
    fi
}

if [[ "$RUNCMD_MODE" == "yes" ]]; then
    output_nomad_config --runcmd
fi
