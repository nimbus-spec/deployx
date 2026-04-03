#!/bin/bash
# bin/detect.sh - Hardware detection
# Usage: source <(./bin/detect.sh) or ./bin/detect.sh
# Output: CPU_CORES, MEMORY_MB, DISK_GB

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

detect_cpu_cores() {
    nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1"
}

detect_memory_mb() {
    local mem_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    echo $((mem_kb / 1024))
}

detect_disk_gb() {
    local disk_kb=$(df -k / 2>/dev/null | tail -1 | awk '{print $2}')
    echo $((disk_kb / 1024 / 1024))
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "CPU_CORES=$(detect_cpu_cores)"
    echo "MEMORY_MB=$(detect_memory_mb)"
    echo "DISK_GB=$(detect_disk_gb)"
else
    CPU_CORES=$(detect_cpu_cores)
    MEMORY_MB=$(detect_memory_mb)
    DISK_GB=$(detect_disk_gb)
fi
