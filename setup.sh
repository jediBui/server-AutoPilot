#!/usr/bin/env bash

# --- CONFIGURATION ---
readonly GH_USER="jediBui"
readonly TARGET_USER="${SUDO_USER:-$USER}"
readonly TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

# TARS-style logging: Humor at 70%, Efficiency at 100%.
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

[[ $EUID -ne 0 ]] && log "red" "Error: Run with sudo. I can't recalibrate the ship without root access." && exit 1

# 1. Environment Detection
HAS_GUI=false
if command -v Xorg >/dev/null || [ -d /usr/share/xsessions ]; then
    HAS_GUI=true
    log "yellow" "GUI detected. Prepping RDP over port 3389."
fi

# 2. Package Installation
log "yellow" "Installing tools, Proxmox Agent, and Starship..."
apt update && apt install -y \
    curl git openssh-server bash-completion fzf ufw qemu-guest-agent \
    $( [ "$HAS_GUI" = true ] && echo "xrdp" )

# 3. Services & Firewall
systemctl enable --now qemu-guest-agent
if [ "$HAS_GUI" = true ]; then
    systemctl enable --now xrdp
    adduser xrdp ssl-cert
    ufw allow 3389/tcp
fi
ufw allow ssh
ufw --force enable

# 4. SSH & Keys
log "yellow" "Importing GitHub keys for ${GH_USER}..."
install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.ssh"
curl -s "https://github.com/${GH_USER}.keys" >> "$TARGET_HOME/.ssh/authorized_keys"
chmod 600 "$TARGET_HOME/.ssh/authorized_keys"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.ssh"

cat <<EOF > /etc/ssh/sshd_config.d/99-hardened.conf
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
EOF
systemctl restart ssh

# 5. Starship & Custom One Dark Configuration
if ! command -v starship &>/dev/null; then
    log "yellow" "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

log "yellow" "Injecting authentic One Dark palette into Starship..."
THEME_DIR="$TARGET_HOME/.config/starship_themes"
mkdir -p "$THEME_DIR"

# Manually building the One Dark Lean theme
cat <<EOF > "$THEME_DIR/onedark.toml"
format = "\$directory\$git_branch\$git_status\$character"
add_newline = false

[directory]
style = "bold #61afef"
format = "[$path](\$style) "
truncation_length = 3

[character]
success_symbol = "[❯](bold #98c379)"
error_symbol = "[❯](bold #e06c75)"

[git_branch]
symbol = " "
style = "bold #c678dd"
format = "on [\$symbol\$branch](\$style) "

[git_status]
style = "bold #e06c75"
format = "([\[\$all_status\$ahead_behind\]](\$style) )"
EOF

# Backup Frappe preset
starship preset catppuccin-powerline -o "$THEME_DIR/catppuccin.toml"

# Link One Dark as default
ln -sf "$THEME_DIR/onedark.toml" "$TARGET_HOME/.config/starship.toml"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"

# 6. Deploy .bashrc
log "yellow" "Applying final cockpit settings to .bashrc..."
[ -f "$TARGET_HOME/.bashrc" ] && cp "$TARGET_HOME/.bashrc" "$TARGET_HOME/.bashrc.bak"

cat <<'EOF' > "$TARGET_HOME/.bashrc"
# TARS SYSTEM CONFIG
[ -z "$PS1" ] && return
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=10000

# Starship Initialization
eval "$(starship init bash)"

# Theme Swapping
alias theme-dark='ln -sf ~/.config/starship_themes/onedark.toml ~/.config/starship.toml && echo "TARS: Authentic One Dark active."'
alias theme-frappe='ln -sf ~/.config/starship_themes/catppuccin.toml ~/.config/starship.toml && echo "TARS: Catppuccin active."'

# FZF & Smart History
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

alias ll='ls -alF --color=auto'
alias ..='cd ..'
EOF

chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.bashrc"

log "green" "Tokyo Night has been jettisoned. One Dark is now primary."
