#!/usr/bin/env bash
set -e

# TARS: Setting honesty to 95% and efficiency to 100%.
echo "Initializing Ansible propulsion..."

# 1. Install Ansible (minimal dependencies)
apt update && apt install -y ansible

# 2. Execute the Playbook
# --become-pass allows the playbook to use your sudo privileges
ansible-playbook setup.yml --ask-become-pass

echo "Mission complete. You can take it from here."
