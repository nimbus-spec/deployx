#!/bin/bash
# bin/detect.sh - Hardware detection

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_DIR/lib/output.sh"

detect_cpu_cores() {
    nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo || echo "1"
}

detect_memory_mb() {
    free -m 2>/dev/null | awk '/^Mem:/{print int($2)}' || echo "1024"
}

detect_disk_gb() {
    df -BG / 2>/dev/null | awk 'NR==2 {print int($2)}' | tr -d 'G' || echo "10"
}

main() {
    header "Hardware Detection"
    
    CPU=$(detect_cpu_cores)
    MEM=$(detect_memory_mb)
    DISK=$(detect_disk_gb)
    
    info "CPU cores: $CPU"
    info "Memory: ${MEM}MB"
    info "Disk: ${DISK}GB"
    
    echo ""
    echo "CPU_CORES=$CPU"
    echo "MEMORY_MB=$MEM"
    echo "DISK_GB=$DISK"
}

main "$@"
