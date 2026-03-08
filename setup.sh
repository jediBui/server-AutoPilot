#!/usr/bin/env bash

# --- CONFIGURATION ---
readonly GH_USER="jediBui"
readonly TARGET_USER="${SUDO_USER:-$USER}"
readonly TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

# --- UI HELPER ---
log() {
    local color="$1"; shift
    local yellow='\033[1;33m' green='\033[0;32m' red='\033[0;31m' nc='\033[0m'
    echo -e "${!color}TARS: $*$nc"
}

# 1. Root & Environment Check
[[ $EUID -ne 0 ]] && log "red" "Self-destruct sequence initiated (or you just forgot sudo)." && exit 1

log "yellow" "Beginning server configuration... I have a cue light I can use to show you when I'm joking."

# 2. Package Management
log "yellow" "Updating system and installing modern essentials..."
apt update && apt install -y curl git zsh openssh-server bash-completion fzf

# 3. Starship Installation (Idempotent)
if ! command -v starship &>/dev/null; then
    log "yellow" "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# 4. SSH Hardening & Key Import
log "yellow" "Hardening SSH for user: $TARGET_USER"
install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.ssh"

# Fetch GitHub keys directly to authorized_keys
if curl -s "https://github.com/${GH_USER}.keys" | tee -a "$TARGET_HOME/.ssh/authorized_keys" >/dev/null; then
    chmod 600 "$TARGET_HOME/.ssh/authorized_keys"
    chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.ssh/authorized_keys"
fi

# Modern SSH config (using a drop-in file is cleaner than sed-ing the main config)
cat <<EOF > /etc/ssh/sshd_config.d/99-hardened.conf
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
EOF

# 5. Bashrc Refinement
log "yellow" "Injecting Starship and fzf into .bashrc..."

# Use a marker to ensure we don't double-write
MARKER="# [TARS-MODERN-TERMINAL]"
if ! grep -q "$MARKER" "$TARGET_HOME/.bashrc"; then
    cat <<EOF >> "$TARGET_HOME/.bashrc"

$MARKER
eval "\$(starship init bash)"
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash
EOF
fi

# 6. Finalize
systemctl restart ssh
log "green" "Configuration complete. I'll be in the ship."
log "yellow" "WARNING: Test SSH in a new terminal before closing this one. Don't make me come get you."
