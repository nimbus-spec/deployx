#cloud-config
# ========================================
# VPS è‡ªåŠ¨éƒ¨ç½²é…ç½®
# Hostname: {{ HOSTNAME }}
# Nomad Role: {{ NOMAD_ROLE }}
# ========================================

# ä¸»æœºå
hostname: {{ HOSTNAME }}
manage_etc_hosts: true

# ç”¨æˆ·é…ç½®
users:
  - name: deploy
    passwd: "{{ PASSWORD_HASH }}"
    ssh_authorized_keys:
      - {{ SSH_KEY }}
    groups: sudo
    sudo: ALL=(ALL) NOPASSWD: ALL
    shell: /bin/bash
    lock_passwd: false

# SSH é…ç½®
ssh_pwauth: false
disable_root: true

write_files:
  - path: /etc/ssh/sshd_config.d/custom.conf
    permissions: '0600'
    content: |
      Port {{ SSH_PORT }}
      PermitRootLogin no
      PasswordAuthentication no
      PubkeyAuthentication yes
      AllowUsers deploy
      ClientAliveInterval 300
      MaxAuthTries 3
      X11Forwarding no
      AllowTcpForwarding no
      UseDNS no
      PrintMotd no

# æ—¶åŒºå’Œ NTP
timezone: UTC
ntp:
  enabled: true
  servers:
    - 0.pool.ntp.org
    - 1.pool.ntp.org
    - time.google.com

# ç½‘ç»œé…ç½®
network:
  version: 2
  ethernets:
    eth0:
{{ NETWORK_CONFIG }}

# åŒ…æ›´æ–°
package_update: true
package_upgrade: true

# å®‰è£…åŒ…
packages:
  - curl wget vim net-tools iputils-ping dnsutils htop tree rsync
  - ca-certificates gnupg apt-transport-https jq sudo iproute2

# å®‰è£…åŽæ‰§è¡Œ
runcmd:
{{ RUNCMD }}

# æ¸…ç†
power_state:
  mode: reboot
  timeout: 120
  condition: true
