#!/usr/bin/env bash

# --- CONFIGURATION ---
readonly GH_USER="jediBui"
readonly TARGET_USER="${SUDO_USER:-$USER}"
readonly TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

# TARS-style logging: Humor 70%, Reliability 100%.
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

# Ensure we aren't flying blind
[[ $EUID -ne 0 ]] && log "red" "Error: Run with sudo. I need keys to the engine room." && exit 1

# 1. Environment Detection (Desktop/GUI)
HAS_GUI=false
if command -v Xorg >/dev/null || [ -d /usr/share/xsessions ]; then
    HAS_GUI=true
    log "yellow" "GUI detected. Prepping RDP and visual interfaces."
fi

# 2. Package Installation
log "yellow" "Installing tools, Proxmox Agent, and Starship..."
apt update && apt install -y \
    curl git openssh-server bash-completion fzf ufw qemu-guest-agent \
    $( [ "$HAS_GUI" = true ] && echo "xrdp" )

# 3. Services & Firewall
log "yellow" "Opening comms channels and securing the hull..."
systemctl enable --now qemu-guest-agent

if [ "$HAS_GUI" = true ]; then
    systemctl enable --now xrdp
    adduser xrdp ssl-cert
    ufw allow 3389/tcp
fi

ufw allow ssh
ufw --force enable

# 4. SSH & Keys
log "yellow" "Syncing GitHub keys for ${GH_USER}..."
install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.ssh"
curl -s "https://github.com/${GH_USER}.keys" >> "$TARGET_HOME/.ssh/authorized_keys"
chmod 600 "$TARGET_HOME/.ssh/authorized_keys"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.ssh"

cat <<EOF > /etc/ssh/sshd_config.d/99-hardened.conf
PasswordAuthentication no
PubkeyAuthentication yes
PermitRoot
