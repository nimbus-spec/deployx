#!/bin/bash
# DeployX - One-Click VPS Deployment
# Usage: curl -fsSL https://raw.githubusercontent.com/nimbus-spec/deployx/main/deployx.sh | bash

# Force UTF-8 encoding to prevent garbled Chinese characters
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

set -e

REPO_URL="https://raw.githubusercontent.com/nimbus-spec/deployx/main"
SUPPORTED_ARCH="x86_64 aarch64 armv7l"

check_encoding() {
    if [ -z "$LC_ALL" ] || [ "$LC_ALL" != "C.UTF-8" ]; then
        export LC_ALL=C.UTF-8
        export LANG=C.UTF-8
    fi
    
    if ! locale -a 2>/dev/null | grep -qi "utf8\|utf-8"; then
        if command -v apt-get &>/dev/null; then
            apt-get update -qq 2>/dev/null
            apt-get install -y -qq locales 2>/dev/null
            locale-gen en_US.UTF-8 2>/dev/null || true
            locale-gen zh_CN.UTF-8 2>/dev/null || true
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
        fi
    fi
}

check_deps() {
    local missing=()
    
    for cmd in bash curl wget openssl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "[!] Missing dependencies: ${missing[*]}"
        echo "[*] Installing missing packages..."
        
        if command -v apt-get &>/dev/null; then
            apt-get update -qq
            apt-get install -y -qq "${missing[@]}" 2>/dev/null || {
                echo "[!] Failed to install dependencies. Please install manually:"
                echo "    apt-get install ${missing[*]}"
                exit 1
            }
        elif command -v yum &>/dev/null; then
            yum install -y -q "${missing[@]}" 2>/dev/null || {
                echo "[!] Failed to install dependencies. Please install manually:"
                echo "    yum install ${missing[*]}"
                exit 1
            }
        elif command -v apk &>/dev/null; then
            apk add "${missing[@]}" 2>/dev/null || {
                echo "[!] Failed to install dependencies. Please install manually:"
                echo "    apk add ${missing[*]}"
                exit 1
            }
        else
            echo "[!] Cannot auto-install. Please install: ${missing[*]}"
            exit 1
        fi
    fi
    
    echo "[+] Dependencies OK"
}

check_arch() {
    local arch=$(uname -m)
    local supported=0
    
    case "$arch" in
        x86_64|amd64)
            echo "[*] Architecture: x86_64 (64-bit) - Supported"
            supported=1
            ;;
        aarch64|arm64)
            echo "[*] Architecture: aarch64 (ARM 64-bit) - Supported"
            supported=1
            ;;
        armv7l|armhf)
            echo "[*] Architecture: armv7l (ARM 32-bit) - Supported"
            supported=1
            ;;
        *)
            echo "[!] Architecture: $arch - Not tested"
            ;;
    esac
    
    if [ $supported -eq 0 ]; then
        echo "[!] This architecture may not be fully supported by reinstall script"
        echo "[*] Proceeding anyway..."
    fi
}

download_file() {
    local path="$1"
    local dest="$2"
    local name="$3"
    
    echo "[*] Downloading $name..."
    
    if command -v curl &>/dev/null; then
        curl -fsSL "$REPO_URL/$path" -o "$dest" || {
            echo "[!] Failed to download $name from curl, trying wget..."
            wget -q "$REPO_URL/$path" -O "$dest" || {
                echo "[!] Failed to download $name"
                return 1
            }
        }
    else
        wget -q "$REPO_URL/$path" -O "$dest" || {
            echo "[!] Failed to download $name"
            return 1
        }
    fi
    
    echo "[+] Downloaded $name"
    return 0
}

main() {
    echo "=============================================="
    echo "  DeployX - VPS Auto Deployment Tool"
    echo "=============================================="
    echo ""
    
    echo "[*] Checking system..."
    check_encoding
    check_arch
    check_deps
    
    echo ""
    echo "[*] Creating working directory..."
    local tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    
    trap "rm -rf '$tmp_dir'" EXIT
    
    echo "[*] Working directory: $tmp_dir"
    echo ""
    
    local dirs=("lib" "bin" "templates" "config" "translations")
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    
    echo "[*] Downloading DeployX..."
    echo ""
    
    download_file "deployx.sh" "deployx.sh" "bootstrap script"
    download_file "generate.sh" "generate.sh" "main script"
    
    echo ""
    echo "[*] Downloading library files..."
    download_file "lib/output.sh" "lib/output.sh" "output library"
    download_file "lib/detect.sh" "lib/detect.sh" "detect library"
    download_file "lib/network.sh" "lib/network.sh" "network library"
    download_file "lib/i18n.sh" "lib/i18n.sh" "i18n library"
    
    echo ""
    echo "[*] Downloading binaries..."
    download_file "bin/detect.sh" "bin/detect.sh" "detect script"
    download_file "bin/network.sh" "bin/network.sh" "network script"
    download_file "bin/hostname.sh" "bin/hostname.sh" "hostname script"
    
    echo ""
    echo "[*] Downloading templates..."
    download_file "templates/user-data.tpl" "templates/user-data.tpl" "user-data template"
    download_file "templates/meta-data.tpl" "templates/meta-data.tpl" "meta-data template"
    
    echo ""
    echo "[*] Downloading configuration..."
    download_file "config/region-codes.conf" "config/region-codes.conf" "region codes"
    
    echo ""
    echo "[*] Downloading translations..."
    download_file "translations/en.sh" "translations/en.sh" "English translations"
    download_file "translations/zh.sh" "translations/zh.sh" "Chinese translations"
    
    chmod +x generate.sh
    chmod +x deployx.sh
    chmod +x bin/*.sh
    
    echo ""
    echo "[+] DeployX downloaded successfully!"
    echo ""
    echo "=============================================="
    echo "[*] Starting deployment wizard..."
    echo "=============================================="
    echo ""
    
    export LC_ALL=C.UTF-8
    export LANG=C.UTF-8
    
    bash generate.sh "$@"
    local exit_code=$?
    
    echo ""
    echo "[*] Done. Exit code: $exit_code"
    
    exit $exit_code
}

main "$@"
