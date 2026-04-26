#!/usr/bin/env bash
# bootstrap.sh — installs Ansible and runs the provisioning playbook
# Usage: sudo bash bootstrap.sh
# Tested on: Ubuntu 26.04 LTS (Resolute)
set -euo pipefail

GITHUB_USER="jediBui"
GITHUB_REPO="server-AutoPilot"
PLAYBOOK_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main/main.yml"
PLAYBOOK="/tmp/main.yml"
ANSIBLE_CFG="/tmp/ansible.cfg"
ANSIBLE_CFG_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main/ansible.cfg"

# ── Must run as root ───────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash bootstrap.sh"
  exit 1
fi

# Keep track of the real user who invoked sudo
REAL_USER="${SUDO_USER:-$USER}"

# ── Purge stale repo sources BEFORE any apt call ───────────────────────────────
# Any leftover Ansible PPA or Chrome list file causes apt-get update to exit
# non-zero, which trips set -e and kills the script immediately. Must run first.
echo "Cleaning stale apt sources..."

for f in \
  /etc/apt/sources.list.d/ansible-ubuntu-ansible-*.list \
  /etc/apt/sources.list.d/ansible-ubuntu-ansible-*.sources \
  /usr/share/keyrings/ansible*.gpg \
  /usr/share/keyrings/ansible*.asc; do
  rm -f "$f"
done

rm -f \
  /etc/apt/sources.list.d/google-chrome*.list \
  /etc/apt/sources.list.d/google-chrome*.sources \
  /usr/share/keyrings/google-chrome.asc \
  /usr/share/keyrings/google-chrome.gpg

# ── System update ──────────────────────────────────────────────────────────────
echo "Updating system..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# ── Install Ansible via pipx ───────────────────────────────────────────────────
# The ansible/ansible PPA does not publish a release file for Ubuntu 26.04
# (Resolute). pipx is the recommended, distro-agnostic install method and
# avoids the externally-managed-environment restrictions in Python 3.12+.
if ! command -v ansible-playbook &>/dev/null; then
  echo "Installing Ansible via pipx..."
  apt-get install -y -qq python3-pip python3-venv pipx
  # Install into root's home so the playbook run below finds it immediately
  pipx install --include-deps ansible
  pipx ensurepath
  # Expose the pipx bin dir in the current session without starting a new shell
  export PATH="${PATH}:/root/.local/bin"
  echo "Ansible $(ansible --version | head -1) installed."
fi

# ── Download and run the playbook ─────────────────────────────────────────────
echo "Downloading playbook..."
curl -fsSL "$PLAYBOOK_URL"     -o "$PLAYBOOK"
curl -fsSL "$ANSIBLE_CFG_URL"  -o "$ANSIBLE_CFG"

echo "Running playbook..."
ANSIBLE_CONFIG="$ANSIBLE_CFG" \
ANSIBLE_FORCE_COLOR=1 \
ansible-playbook \
  --connection=local \
  --inventory "localhost," \
  -e "target_user=${REAL_USER}" \
  -e "ansible_python_interpreter=$(command -v python3)" \
  "$PLAYBOOK"

echo ""
echo "Done! Reboot recommended: sudo reboot"
