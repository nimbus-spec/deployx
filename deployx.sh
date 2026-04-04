#!/bin/bash
# deployx.sh - DeployX Bootstrap Script
# Usage: curl -fsSL https://raw.githubusercontent.com/nimbus-spec/deployx/main/deployx.sh | bash
# 
# This script downloads all DeployX components and runs the wizard.
# It ensures UTF-8 encoding and proper execution environment.

set -uo pipefail

REPO="nimbus-spec/deployx"
BRANCH="${BRANCH:-main}"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

TEMP_DIR=""
CLEANUP_DONE=0

cleanup() {
    if [[ $CLEANUP_DONE -eq 0 ]] && [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
        CLEANUP_DONE=1
    fi
}

trap cleanup EXIT INT TERM

setup_locale() {
    export LANG="${LANG:-en_US.UTF-8}"
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    
    if locale-check 2>/dev/null || locale -a 2>/dev/null | grep -qi "utf8\|utf-8"; then
        return 0
    fi
    
    for loc in "en_US.UTF-8" "C.UTF-8" "POSIX"; do
        if locale -a 2>/dev/null | grep -qi "^$loc"; then
            export LANG="$loc"
            export LC_ALL="$loc"
            return 0
        fi
    done
}

check_dependencies() {
    local deps=("curl" "bash")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "[ERROR] Missing dependencies: ${missing[*]}"
        exit 1
    fi
}

download_file() {
    local remote_path="$1"
    local local_path="$2"
    local url="${BASE_URL}/${remote_path}"
    
    echo "[*] Downloading $remote_path..."
    
    if ! curl -fsSL "$url" -o "$local_path" 2>/dev/null; then
        echo "[ERROR] Failed to download $remote_path"
        return 1
    fi
    
    return 0
}

download_all() {
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    echo "[*] DeployX Bootstrap"
    echo "[*] Repository: $REPO"
    echo "[*] Branch: $BRANCH"
    echo ""
    
    mkdir -p bin lib templates translations config
    
    download_file "generate.sh" "generate.sh" || return 1
    download_file "bin/detect.sh" "bin/detect.sh" || return 1
    download_file "bin/network.sh" "bin/network.sh" || return 1
    download_file "bin/location.sh" "bin/location.sh" || return 1
    download_file "bin/hostname.sh" "bin/hostname.sh" || return 1
    download_file "bin/nomad.sh" "bin/nomad.sh" || return 1
    download_file "bin/tailscale.sh" "bin/tailscale.sh" || return 1
    download_file "bin/render.sh" "bin/render.sh" || return 1
    download_file "bin/install.sh" "bin/install.sh" || return 1
    download_file "bin/execute.sh" "bin/execute.sh" || return 1
    download_file "lib/output.sh" "lib/output.sh" || return 1
    download_file "lib/i18n.sh" "lib/i18n.sh" || return 1
    download_file "templates/user-data.tpl" "templates/user-data.tpl" || return 1
    download_file "templates/meta-data.tpl" "templates/meta-data.tpl" || return 1
    download_file "translations/en.sh" "translations/en.sh" || return 1
    download_file "translations/zh.sh" "translations/zh.sh" || return 1
    
    chmod +x generate.sh
    chmod +x bin/*.sh
    
    echo ""
    echo "[+] All files downloaded successfully"
}

run_generate() {
    echo ""
    echo "[*] Starting DeployX Wizard..."
    echo ""
    
    cd "$TEMP_DIR"
    ./generate.sh "$@"
}

run_execute() {
    echo ""
    echo "[*] Starting DeployX Installation..."
    echo ""
    
    cd "$TEMP_DIR"
    ./generate.sh --execute "$@"
}

main() {
    setup_locale
    check_dependencies
    download_all
    
    # Parse global flags
    local execute_mode=no
    local args=()
    for arg in "$@"; do
        case "$arg" in
            --execute) execute_mode=yes ;;
            --help) show_help; exit 0 ;;
            --version) echo "$VERSION"; exit 0 ;;
            *) args+=("$arg") ;;
        esac
    done
    
    if [[ "$execute_mode" == "yes" ]]; then
        run_execute "${args[@]}"
    else
        run_generate "${args[@]}"
    fi
}

show_help() {
    cat << EOF
Usage: $0 [options]
Options:
    --execute   Execute installation after generating config
    --help      Show this help message
    --version   Show version information
    
Examples:
    $0                     # Generate config only (interactive)
    $0 --execute           # Generate config and execute installation
EOF
}

main "$@"
