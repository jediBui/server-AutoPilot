#!/usr/bin/env bash

# --- CONFIGURATION ---
readonly GH_USER="jediBui"
readonly TARGET_USER="${SUDO_USER:-$USER}"
readonly TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

# TARS-style logging
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

[[ $EUID -ne 0 ]] && log "red" "Error: Run with sudo. This is a restricted area." && exit 1

# 1. Environment & Dependencies
HAS_GUI=false
[[ $(command -v Xorg) || -d /usr/share/xsessions ]] && HAS_GUI=true

log "yellow" "Installing tools, QEMU Agent, and aesthetics..."
apt update && apt install -y \
    curl git openssh-server bash-completion fzf ufw qemu-guest-agent \
    $( [ "$HAS_GUI" = true ] && echo "xrdp" )

# 2. Services & Firewall
systemctl enable --now qemu-guest-agent
if [ "$HAS_GUI" = true ]; then
    systemctl enable --now xrdp
    adduser xrdp ssl-cert
    ufw allow 3389/tcp
fi
ufw allow ssh
ufw --force enable

# 3. SSH Keys
log "yellow" "Downloading GitHub keys for ${GH_USER}..."
install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.ssh"
curl -s "https://github.com/${GH_USER}.keys" >> "$TARGET_HOME/.ssh/authorized_keys"
chmod 600 "$TARGET_HOME/.ssh/authorized_keys"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.ssh"

# 4. Starship Installation
if ! command -v starship &>/dev/null; then
    log "yellow" "Installing Starship HUD..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# 5. Theme Management (Corrected Preset Names)
log "yellow" "Correcting theme presets... adjusting navigation coordinates."
THEME_DIR="$TARGET_HOME/.config/starship_themes"
mkdir -p "$THEME_DIR"

# Generate Tokyo Night (Our One Dark stand-in)
starship preset tokyo-night -o "$THEME_DIR/onedark.toml"

# Generate Catppuccin (The Frappé backup)
starship preset catppuccin-powerline -o "$THEME_DIR/catppuccin.toml"

# Set default link
ln -sf "$THEME_DIR/onedark.toml" "$TARGET_HOME/.config/starship.toml"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"

# 6. DEPLOY CUSTOM .BASHRC
log "yellow" "Updating .bashrc with theme-switching aliases..."
cp "$TARGET_HOME/.bashrc" "$TARGET_HOME/.bashrc.bak"

cat <<'EOF' > "$TARGET_HOME/.bashrc"
# TARS SYSTEM CONFIG
[ -z "$PS1" ] && return
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=10000

# Starship Init
eval "$(starship init bash)"

# Theme Swapping Aliases
alias theme-dark='ln -sf ~/.config/starship_themes/onedark.toml ~/.config/starship.toml && echo "TARS: One Dark active."'
alias theme-frappe='ln -sf ~/.config/starship_themes/catppuccin.toml ~/.config/starship.toml && echo "TARS: Catppuccin Frappe active."'

# FZF & History
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

alias ll='ls -alF --color=auto'
alias ..='cd ..'
EOF

chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.bashrc"

log "green" "Themes deployed. Use 'theme-frappe' if you want that latte-colored comfort."
