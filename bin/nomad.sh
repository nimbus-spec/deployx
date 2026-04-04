#!/bin/bash
# bin/nomad.sh - Nomad configuration generator
# Usage: ./bin/nomad.sh -r ROLE -n HOSTNAME [--runcmd]

ROLE=""
HOSTNAME=""
RUNCMD_MODE="no"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r) ROLE="$2"; shift 2 ;;
        -n) HOSTNAME="$2"; shift 2 ;;
        --runcmd) RUNCMD_MODE="yes"; shift ;;
        *) shift ;;
    esac
done

if [[ -z "$ROLE" ]] || [[ -z "$HOSTNAME" ]]; then
    echo "Usage: $0 -r ROLE -n HOSTNAME [--runcmd]" >&2
    exit 1
fi

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
    
    case "$ROLE" in
        server|server+client)
            echo ""
            echo "server {"
            echo "  enabled = true"
            echo "  bootstrap_expect = 1"
            echo "}"
            ;;
    esac
    
    case "$ROLE" in
        client|server+client)
            echo ""
            echo "client {"
            echo "  enabled = true"
            echo "  servers = [\"127.0.0.1:4647\"]"
            echo "}"
            ;;
    esac
    
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
