#!/usr/bin/env bash
# bootstrap.sh — installs Ansible and runs the provisioning playbook
# Usage: sudo bash bootstrap.sh
set -euo pipefail

GITHUB_USER="jediBui"
GITHUB_REPO="server-AutoPilot"
PLAYBOOK_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main/main.yml"
PLAYBOOK="/tmp/main.yml"
ANSIBLE_CFG="/tmp/ansible.cfg"
ANSIBLE_CFG_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main/ansible.cfg"

# ── Must run as root ──────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash bootstrap.sh"
  exit 1
fi

# Keep track of the real user who invoked sudo
REAL_USER="${SUDO_USER:-$USER}"

# ── System update ────────────────────────────────────────────────────────────
# echo "Updating system..."
# apt-get update -qq
# DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# ── Install Ansible if missing ────────────────────────────────────────────────
if ! command -v ansible-playbook &>/dev/null; then
  echo "Installing Ansible via pipx..."
  apt-get install -y -qq python3-pip python3-venv pipx
  pipx install --include-deps ansible
  pipx ensurepath
  # Make ansible available to root in this session
  export PATH="$PATH:/root/.local/bin"

  # Ansible PPA doesn't publish for non-LTS releases (e.g. resolute).
  # Pin to noble (24.04 LTS) which is always supported.
  UBUNTU_CODENAME="$(lsb_release -cs)"
  PPA_CODENAME="noble"
  case "$UBUNTU_CODENAME" in
    noble|jammy|focal) PPA_CODENAME="$UBUNTU_CODENAME" ;;
  esac

  curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x6125E2A8C77F2818FB7BD15B93C4A3FD7BB9C367" \
    | gpg --dearmor -o /usr/share/keyrings/ansible-archive-keyring.gpg

  echo "deb [signed-by=/usr/share/keyrings/ansible-archive-keyring.gpg] https://ppa.launchpadcontent.net/ansible/ansible/ubuntu ${PPA_CODENAME} main" \
    > /etc/apt/sources.list.d/ansible.list

  apt-get update -qq
  apt-get install -y -qq ansible
fi
# ── Clear any leftover Chrome repo conflicts ──────────────────────────────────
rm -f /etc/apt/sources.list.d/google-chrome*.list \
      /usr/share/keyrings/google-chrome.asc \
      /usr/share/keyrings/google-chrome.gpg

# ── Download and run the playbook ─────────────────────────────────────────────
echo "Downloading playbook..."
curl -fsSL "$PLAYBOOK_URL" -o "$PLAYBOOK"
curl -fsSL "$ANSIBLE_CFG_URL" -o "$ANSIBLE_CFG"

echo "Running playbook..."
ANSIBLE_CONFIG="$ANSIBLE_CFG" ANSIBLE_FORCE_COLOR=1 ansible-playbook \
  --connection=local \
  --inventory "localhost," \
  -e "target_user=${REAL_USER}" \
  -e "ansible_python_interpreter=$(which python3)" \
  "$PLAYBOOK"

echo ""
echo "Done! Reboot recommended: sudo reboot"
