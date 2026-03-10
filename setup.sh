#!/usr/bin/env bash

# --- CONFIGURATION ---
readonly GH_USER="jediBui"
readonly TARGET_USER="${SUDO_USER:-$USER}"
readonly TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

# TARS-style logging: 100% helpful, 70% humor.
log() {
    local color="$1"; shift
    local red='\033[0;31m' green='\033[0;32m' yellow='\033[1;33m' nc='\033[0m'
    case "$color" in
        "red")    local code=$red ;;
        "green")  local code=$green ;;
        "yellow") local code=$yellow ;;
        *)        local code=$nc ;;
    esac
    echo -e "${code}TARS: $*$nc"
}

# Ensure we aren't trying to fly without a pilot
[[ $EUID -ne 0 ]] && log "red" "Error: Run with sudo. I can't move the bulkheads without authorization." && exit 1

# 1. Environment Detection (GUI & Virtualization)
HAS_GUI=false
if command -v Xorg >/dev/null || [ -d /usr/share/xsessions ]; then
    HAS_GUI=true
    log "yellow" "GUI detected. Prepping the visual interface for RDP."
fi

# 2. Dependencies & QEMU Agent
log "yellow" "Installing tools, Proxmox QEMU Agent, and aesthetics..."
apt update && apt install -y \
    curl git openssh-server bash-completion fzf ufw qemu-guest-agent \
    $( [ "$HAS_GUI" = true ] && echo "xrdp" )

# 3. Enable Services & Firewall
log "yellow" "Establishing communication links and perimeter defense..."
systemctl enable --now qemu-guest-agent

if [ "$HAS_GUI" = true ]; then
    systemctl enable --now xrdp
    # Allow xrdp to access SSL certs
    adduser xrdp ssl-cert
    ufw allow 3389/tcp
fi

ufw allow ssh
ufw --force enable

# 4. SSH & Keys
log "yellow" "Retrieving GitHub keys for ${GH_USER}... locking the hatch behind them."
install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.ssh"
curl -s "https://github.com/${GH_USER}.keys" >> "$TARGET_HOME/.ssh/authorized_keys"
chmod 600 "$TARGET_HOME/.ssh/authorized_keys"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME
