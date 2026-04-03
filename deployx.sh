#!/bin/bash
# DeployX - One-Click VPS Deployment
# Usage: curl -fsSL https://raw.githubusercontent.com/nimbus-spec/deployx/main/generate.sh | bash

set -e

INSTALL_URL="https://raw.githubusercontent.com/nimbus-spec/deployx/main/generate.sh"
REPO_URL="https://github.com/nimbus-spec/deployx"

main() {
    echo "=============================================="
    echo "  DeployX - VPS Auto Deployment Tool"
    echo "=============================================="
    echo ""
    
    local tmp_dir=$(mktemp -d)
    local script_file="$tmp_dir/generate.sh"
    
    echo "[*] Downloading from $INSTALL_URL ..."
    
    if command -v curl &>/dev/null; then
        curl -fsSL "$INSTALL_URL" -o "$script_file" || {
            echo "[!] Download failed with curl"
            exit 1
        }
    elif command -v wget &>/dev/null; then
        wget -q "$INSTALL_URL" -O "$script_file" || {
            echo "[!] Download failed with wget"
            exit 1
        }
    else
        echo "[!] Neither curl nor wget found"
        exit 1
    fi
    
    chmod +x "$script_file"
    
    echo "[*] Running generate.sh ..."
    echo ""
    
    cd "$tmp_dir"
    bash "$script_file" "$@"
    local exit_code=$?
    
    rm -rf "$tmp_dir"
    
    exit $exit_code
}

main "$@"
