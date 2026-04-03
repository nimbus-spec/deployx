#!/bin/bash
# DeployX - One-Click VPS Deployment
# Usage: 
#   curl -fsSL https://raw.githubusercontent.com/nimbus-spec/deployx/main/deployx.sh -o deployx.sh
#   chmod +x deployx.sh
#   ./deployx.sh

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

REPO_URL="https://raw.githubusercontent.com/nimbus-spec/deployx/main"

fix_crlf() {
    local file="$1"
    [ -f "$file" ] && sed -i 's/\r$//' "$file" 2>/dev/null
}

check_encoding() {
    if ! locale -a 2>/dev/null | grep -qi "utf"; then
        command -v apt-get &>/dev/null && apt-get install -y locales &>/dev/null
        locale-gen en_US.UTF-8 zh_CN.UTF-8 &>/dev/null || true
    fi
    export LC_ALL=C.UTF-8 LANG=C.UTF-8
}

check_deps() {
    for cmd in bash curl openssl; do
        command -v "$cmd" &>/dev/null || {
            echo "[!] Missing: $cmd"
            exit 1
        }
    done
    echo "[+] Dependencies OK"
}

download() {
    local path="$1" dest="$2" name="$3"
    echo "[*] Downloading $name..."
    curl -fsSL "$REPO_URL/$path" -o "$dest" && fix_crlf "$dest" && echo "[+] $name" || echo "[!] Failed: $name"
}

main() {
    echo "=============================================="
    echo "  DeployX - VPS Auto Deployment Tool"
    echo "=============================================="
    echo ""
    
    check_encoding
    check_deps
    
    local tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    trap "rm -rf '$tmp_dir'" EXIT
    
    echo "[*] Working dir: $tmp_dir"
    mkdir -p lib bin templates config translations
    
    # Download all scripts
    download "deployx.sh" "deployx.sh" "bootstrap"
    download "generate.sh" "generate.sh" "main"
    
    # Download library
    download "lib/output.sh" "lib/output.sh" "output lib"
    download "lib/i18n.sh" "lib/i18n.sh" "i18n lib"
    
    # Download modular bin scripts
    download "bin/detect.sh" "bin/detect.sh" "detect"
    download "bin/network.sh" "bin/network.sh" "network"
    download "bin/location.sh" "bin/location.sh" "location"
    download "bin/hostname.sh" "bin/hostname.sh" "hostname"
    download "bin/nomad.sh" "bin/nomad.sh" "nomad"
    download "bin/tailscale.sh" "bin/tailscale.sh" "tailscale"
    download "bin/render.sh" "bin/render.sh" "render"
    download "bin/install.sh" "bin/install.sh" "install"
    
    # Download templates
    download "templates/user-data.tpl" "templates/user-data.tpl" "user-data"
    download "templates/meta-data.tpl" "templates/meta-data.tpl" "meta-data"
    
    # Download config and translations
    download "config/region-codes.conf" "config/region-codes.conf" "region codes"
    download "translations/en.sh" "translations/en.sh" "English"
    download "translations/zh.sh" "translations/zh.sh" "Chinese"
    
    chmod +x generate.sh bin/*.sh
    
    echo ""
    echo "[+] Download complete!"
    echo ""
    echo "=============================================="
    echo "[*] Starting wizard..."
    echo "=============================================="
    echo ""
    
    export LC_ALL=C.UTF-8 LANG=C.UTF-8
    bash generate.sh "$@"
}

main "$@"
