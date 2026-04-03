#!/bin/bash
# lib/detect.sh - ç¡¬ä»¶æ£€æµ‹å‡½æ•°åº“

# æ£€æµ‹ CPU æ ¸å¿ƒæ•°
detect_cpu_cores() {
    nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo || echo "1"
}

# æ£€æµ‹å†…å­˜ (MB)
detect_memory_mb() {
    free -m 2>/dev/null | awk '/^Mem:/{print int($2)}' || echo "1024"
}

# æ£€æµ‹å†…å­˜ (GB)
detect_memory_gb() {
    local mb=$(detect_memory_mb)
    echo "scale=1; $mb / 1024" | bc 2>/dev/null || echo "1"
}

# æ£€æµ‹ç£ç›˜å¤§å° (GB)
detect_disk_gb() {
    df -BG / 2>/dev/null | awk 'NR==2 {print int($2)}' | tr -d 'G' || echo "10"
}

# æ£€æµ‹ç£ç›˜è®¾å¤‡
detect_disk_device() {
    lsblk -no PKNAME "$(df / | tail -1 | awk '{print $1}')" 2>/dev/null || echo "sda"
}

# æ£€æµ‹ç£ç›˜æ€»å¤§å° (bytes -> GB)
detect_disk_total_gb() {
    local disk=$(detect_disk_device)
    blockdev --getsize64 "/dev/$disk" 2>/dev/null | \
        awk '{print int($1/1024/1024/1024)}' || echo "0"
}

# æ£€æµ‹ç½‘ç»œæŽ¥å£
detect_default_interface() {
    ip route | grep default | awk '{print $5}' | head -1 || echo "eth0"
}

# å®Œæ•´ç¡¬ä»¶æ£€æµ‹
detect_hardware() {
    cat << EOF
CPU_CORES=$(detect_cpu_cores)
MEMORY_MB=$(detect_memory_mb)
MEMORY_GB=$(detect_memory_gb)
DISK_GB=$(detect_disk_gb)
DISK_DEVICE=$(detect_disk_device)
EOF
}
