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

[[ $EUID -ne 0 ]] && log "red" "Error: Run with sudo. I need keys to the cockpit." && exit 1

# 1. Environment Detection
HAS_GNOME=false
[[ $(command -v gnome-shell) ]] && HAS_GNOME=true

# 2. Package Installation
log "yellow" "Installing tools, Proxmox Agent, and RDP..."
apt update && apt install -y \
    curl git openssh-server bash-completion fzf ufw qemu-guest-agent \
    gnome-remote-desktop fontconfig

# 3. Install SF Mono Powerline (Twixes Repository)
log "yellow" "Downloading SF Mono Powerline... It’s an older code, but it checks out."
FONT_DIR="$TARGET_HOME/.local/share/fonts"
sudo -u "$TARGET_USER" mkdir -p "$FONT_DIR"

# Download SF Mono Powerline Regular and Bold
BASE_URL="https://github.com/Twixes/SF-Mono-Powerline/raw/master"
for style in "Regular" "Bold"; do
    if [[ ! -f "$FONT_DIR/SF-Mono-Powerline-$style.otf" ]]; then
        curl -L "$BASE_URL/SF-Mono-Powerline-$style.otf" -o "$FONT_DIR/SF-Mono-Powerline-$style.otf"
    fi
done

sudo -u "$TARGET_USER" fc-cache -f "$FONT_DIR"

# 4. Inject Font into Gnome Terminal
if [ "$HAS_GNOME" = true ]; then
    log "yellow" "Adjusting Gnome Terminal vision sensors..."
    PROFILE=$(sudo -u "$TARGET_USER" gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
    
    # Apply SF Mono Powerline at size 12
    sudo -u "$TARGET_USER" gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE/" use-system-font false
    sudo -u "$TARGET_USER" gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE/" font "'SF Mono Powerline 12'"
fi

# 5. Remote Desktop & Firewall
systemctl enable --now qemu-guest-agent
ufw allow ssh
ufw allow 3389/tcp
ufw --force enable

if [ "$HAS_GNOME" = true ]; then
    log "yellow" "Enabling native Gnome Remote Desktop sharing..."
    sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$TARGET_USER")/bus" \
    gsettings set org.gnome.desktop.remote-desktop.rdp screen-share-mode 'mirror-screen'
    
    sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$TARGET_USER")/bus" \
    gsettings set org.gnome.desktop.remote-desktop.rdp enable true
fi

# 6. SSH & Keys
log "yellow" "Securing the hatch and importing keys from ${GH_USER}..."
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

# 7. Starship Minimalist Themes
log "yellow" "Generating Lean prompt themes..."
THEME_DIR="$TARGET_HOME/.config/starship_themes"
sudo -u "$TARGET_USER" mkdir -p "$THEME_DIR"

for theme in "onedark" "frappe" "mocha"; do
    case $theme in
        "onedark") dir="#61afef"; char="#98c379"; git="#c678dd" ;;
        "frappe")  dir="#8caaee"; char="#a6d189"; git="#ca9ee6" ;;
        "mocha")   dir="#89b4fa"; char="#a6e3a1"; git="#cba6f7" ;;
    esac

cat <<EOF > "$THEME_DIR/${theme}.toml"
format = "\$directory\$git_branch\$git_status\$character"
add_newline = false
[directory]
style = "bold $dir"
format = "[\$path](\$style) "
[character]
success_symbol = "[❯](bold $char)"
error_symbol = "[❯](bold #e06c75)"
[git_branch]
symbol = " "
style = "bold $git"
format = "on [\$symbol\$branch](\$style) "
[git_status]
style = "bold #e06c75"
format = "([\$all_status\$ahead_behind](\$style) )"
EOF
done

sudo -u "$TARGET_USER" ln -sf "$THEME_DIR/onedark.toml" "$TARGET_HOME/.config/starship.toml"

# 8. Bashrc & Aliases
log "yellow" "Updating .bashrc cockpit settings..."
[ -f "$TARGET_HOME/.bashrc" ] && cp "$TARGET_HOME/.bashrc" "$TARGET_HOME/.bashrc.bak"

cat <<'EOF' > "$TARGET_HOME/.bashrc"
# TARS SYSTEM CONFIG
[ -z "$PS1" ] && return
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=10000

eval "$(starship init bash)"

# Theme Swapping
alias theme-dark='ln -sf ~/.config/starship_themes/onedark.toml ~/.config/starship.toml && echo "TARS: One Dark (Lean) active."'
alias theme-frappe='ln -sf ~/.config/starship_themes/frappe.toml ~/.config/starship.toml && echo "TARS: Catppuccin Frappe (Lean) active."'
alias theme-mocha='ln -sf ~/.config/starship_themes/mocha.toml ~/.config/starship.toml && echo "TARS: Catppuccin Mocha (Lean) active."'

# FZF & History
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

alias ll='ls -alF --color=auto'
alias ..='cd ..'
EOF

chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.bashrc"

log "green" "System fully configured. SF Mono Powerline is now the primary font."
