#!/bin/bash

# --- CONFIGURATION ---
GH_USER="jediBui" # <--- CHANGE THIS to your GitHub handle
USER_HOME=$(eval echo ~$USER)

# --- COLORS FOR OUTPUT ---
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}TARS: Beginning server configuration...${NC}"

# 1. Root Check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run with sudo.${NC}"
   exit 1
fi

# 2. Update and Install Core Tools
echo -e "${YELLOW}Installing dependencies (fzf, starship, etc.)...${NC}"
apt update && apt install -y curl git zsh openssh-server bash-completion fzf

# 3. Starship Installation
if ! command -v starship &> /dev/null; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# 4. SSH Configuration (The Security Hardening)
echo -e "${YELLOW}Hardening SSH and importing GitHub keys...${NC}"
mkdir -p "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"

# Fetch keys from GitHub
curl -s "https://github.com/${GH_USER}.keys" >> "$USER_HOME/.ssh/authorized_keys"
chmod 600 "$USER_HOME/.ssh/authorized_keys"
chown -R $USER:$USER "$USER_HOME/.ssh"

# Update SSH Policy: Key-auth only, no root password login
sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# 5. Modernize .bashrc (Idempotent - won't duplicate)
echo -e "${YELLOW}Configuring .bashrc with Starship and fzf...${NC}"

if ! grep -q "ANSIBLE_MANAGED_BLOCK" "$USER_HOME/.bashrc"; then
cat << EOF >> "$USER_HOME/.bashrc"

# --- ANSIBLE_MANAGED_BLOCK: MODERN TERMINAL ---
# Initialize Starship
eval "\$(starship init bash)"

# Enable fzf key bindings and completion
source /usr/share/doc/fzf/examples/key-bindings.bash
source /usr/share/doc/fzf/examples/completion.bash

# Force bash-completion
[[ -f /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion
# --- END BLOCK ---
EOF
fi

# 6. Finalize
systemctl restart ssh
echo -e "${GREEN}Configuration Complete!${NC}"
echo -e "${YELLOW}IMPORTANT: Test your SSH connection in a NEW window before logging out.${NC}"