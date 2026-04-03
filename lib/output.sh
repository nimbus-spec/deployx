#!/bin/bash
# lib/output.sh - è¾“å‡ºå‡½æ•°åº“

# é¢œè‰²å®šä¹‰
export COLOR_RESET='\033[0m'
export COLOR_BOLD='\033[1m'
export COLOR_RED='\033[31m'
export COLOR_GREEN='\033[32m'
export COLOR_YELLOW='\033[33m'
export COLOR_BLUE='\033[34m'
export COLOR_CYAN='\033[36m'

# è¾“å‡ºå‡½æ•°
info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

success() {
    echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*"
}

warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
}

error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${COLOR_CYAN}[DEBUG]${COLOR_RESET} $*"
    fi
}

header() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}=========================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $*${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}=========================================${COLOR_RESET}"
    echo ""
}

section() {
    echo ""
    echo -e "${COLOR_BOLD}[ $* ]${COLOR_RESET}"
}

# ç¡®è®¤æç¤º
confirm() {
    local prompt="${1:-ç»§ç»­?}"
    local default="${2:-no}"
    
    if [[ "$default" == "yes" ]]; then
        read -p "$prompt [yes/no]: " answer
        answer="${answer:-yes}"
    else
        read -p "$prompt [no/yes]: " answer
        answer="${answer:-no}"
    fi
    
    [[ "$answer" == "yes" ]]
}

# è¿›åº¦æ¡
progress() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "] %3d%%" "$percent"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}
