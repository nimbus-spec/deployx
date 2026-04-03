#!/bin/bash
# bin/install.sh - Unified installation entry point
# Usage: ./bin/install.sh [options]
# 
# Supports two modes:
#   1. DD mode: --dd --img URL [--cloud-data DIR]
#   2. Native mode: --os OS [--version VERSION] [reinstall options]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat << EOF
Usage: $0 [options]

DD Mode:
    --dd                    Enable DD mode
    --img URL               DD image URL
    --cloud-data DIR        Cloud-init data directory

Native Mode:
    --os OS                 Operating system (debian, ubuntu, alpine, etc.)
    --version VERSION       OS version (default varies by OS)

Common Options:
    --hostname NAME         Set hostname
    --ssh-key KEY          SSH public key
    --ssh-port PORT        SSH port (default: 22)
    --password PASS        Root password (alternative to ssh-key)
    --cloud-data DIR       Cloud-init data directory

Examples:
    # DD install
    $0 --dd --img "https://example.com/image.raw" --cloud-data /tmp/seed/

    # Native install
    $0 --os debian --version 12 --hostname test --ssh-key "ssh-rsa ..."
EOF
}

# Default values
MODE="native"
OS=""
VERSION=""
HOSTNAME=""
SSH_KEY=""
SSH_PORT="22"
PASSWORD=""
IMAGE_URL=""
CLOUD_DATA=""
DD_MODE="no"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dd) DD_MODE="yes"; MODE="dd"; shift ;;
        --img) IMAGE_URL="$2"; shift 2 ;;
        --os) OS="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --hostname) HOSTNAME="$2"; shift 2 ;;
        --ssh-key) SSH_KEY="$2"; shift 2 ;;
        --ssh-port) SSH_PORT="$2"; shift 2 ;;
        --password) PASSWORD="$2"; shift 2 ;;
        --cloud-data) CLOUD_DATA="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Download reinstall script
download_reinstall() {
    echo "[*] Downloading reinstall script..."
    curl -fsSL https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh -o /tmp/reinstall.sh
    chmod +x /tmp/reinstall.sh
    echo "[+] Downloaded"
}

# Build reinstall command
build_reinstall_cmd() {
    local cmd="/tmp/reinstall.sh"
    
    if [[ "$MODE" == "dd" ]]; then
        cmd="$cmd dd --img '$IMAGE_URL'"
    else
        cmd="$cmd $OS"
        [[ -n "$VERSION" ]] && cmd="$cmd $VERSION"
    fi
    
    [[ -n "$HOSTNAME" ]] && cmd="$cmd --hostname '$HOSTNAME'"
    [[ -n "$SSH_PORT" ]] && cmd="$cmd --ssh-port $SSH_PORT"
    
    if [[ -n "$SSH_KEY" ]]; then
        cmd="$cmd --ssh-key '$SSH_KEY'"
    elif [[ -n "$PASSWORD" ]]; then
        cmd="$cmd --password '$PASSWORD'"
    fi
    
    [[ -n "$CLOUD_DATA" ]] && cmd="$cmd --cloud-data '$CLOUD_DATA'"
    
    echo "$cmd"
}

# Main
main() {
    download_reinstall
    
    local cmd=$(build_reinstall_cmd)
    
    echo ""
    echo "[*] Running installation..."
    echo "[*] Command: $cmd"
    echo ""
    
    eval "$cmd"
}

main
