#!/bin/bash
# bin/execute.sh - Execute installation
# Usage: ./bin/execute.sh --dd --img URL [--os OS --ver VER] [--cloud-data DIR]
# 
# Downloads reinstall script and executes installation with cloud-init data.

set -e

CLOUD_DATA=""
DD_MODE="no"
DD_IMAGE=""
OS=""
OS_VERSION=""

usage() {
    cat << EOF
Usage: $0 [options]
Options:
    --dd              DD mode
    --img URL         DD image URL
    --os OS           OS name (debian, ubuntu, etc.)
    --ver VER         OS version
    --cloud-data DIR  Cloud-init data directory
    -h, --help        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dd) DD_MODE="yes"; shift ;;
        --img) DD_IMAGE="$2"; shift 2 ;;
        --os) OS="$2"; shift 2 ;;
        --ver) OS_VERSION="$2"; shift 2 ;;
        --cloud-data) CLOUD_DATA="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) shift ;;
    esac
done

if [[ "$DD_MODE" == "yes" ]] && [[ -z "$DD_IMAGE" ]]; then
    echo "Error: --img required in DD mode" >&2
    exit 1
fi

echo "[INFO] Downloading reinstall script..."
curl -fsSL https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh -o /tmp/reinstall.sh
chmod +x /tmp/reinstall.sh

if [[ -n "$CLOUD_DATA" ]]; then
    echo "[INFO] Cloud-init data: $CLOUD_DATA"
fi

echo "[INFO] Starting installation..."
if [[ "$DD_MODE" == "yes" ]]; then
    echo "[INFO] Mode: DD"
    echo "[INFO] Image: $DD_IMAGE"
    /tmp/reinstall.sh dd --img "$DD_IMAGE" --cloud-data "$CLOUD_DATA" --force
else
    echo "[INFO] Mode: Native"
    echo "[INFO] OS: $OS $OS_VERSION"
    /tmp/reinstall.sh "$OS" "$OS_VERSION" --cloud-data "$CLOUD_DATA" --force
fi

echo "[INFO] Installation started."
