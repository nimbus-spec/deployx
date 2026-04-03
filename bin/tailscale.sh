#!/bin/bash
# bin/tailscale.sh - Tailscale configuration generator
# Usage: ./bin/tailscale.sh -k AUTH_KEY [-a] [-o OUTPUT_TYPE]
# Output: Tailscale install/run commands

set -e

usage() {
    cat << EOF
Usage: $0 [options]
Options:
    -k AUTH_KEY    Tailscale auth key (tskey-auth-xxx)
    -a            Accept routes from tailnet
    -o TYPE       Output type: runcmd, script (default: runcmd)
    -h            Show this help
EOF
}

AUTH_KEY=""
ACCEPT_ROUTES="no"
OUTPUT_TYPE="runcmd"

while getopts "k:ao:h" opt; do
    case $opt in
        k) AUTH_KEY="$OPTARG" ;;
        a) ACCEPT_ROUTES="yes" ;;
        o) OUTPUT_TYPE="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

[[ -z "$AUTH_KEY" ]] && { echo "Error: -k AUTH_KEY required"; exit 1; }

output_runcmd() {
    local accept_flag=""
    [[ "$ACCEPT_ROUTES" == "yes" ]] && accept_flag="--accept-routes"
    
    cat << RUNCMD
  - |
    curl -fsSL https://tailscale.com/install.sh | sh
    tailscale up --authkey=${AUTH_KEY} ${accept_flag}
RUNCMD
}

output_script() {
    cat << 'SCRIPT'
#!/bin/bash
# Tailscale installation and connection
set -e

echo "[*] Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo "[*] Connecting to Tailscale..."
SCRIPT

    local accept_flag=""
    [[ "$ACCEPT_ROUTES" == "yes" ]] && accept_flag="--accept-routes"
    
    echo "tailscale up --authkey=${AUTH_KEY} ${accept_flag}"
}

case "$OUTPUT_TYPE" in
    runcmd)
        output_runcmd
        ;;
    script)
        output_script
        ;;
    *)
        echo "Error: Unknown output type: $OUTPUT_TYPE"
        exit 1
        ;;
esac
