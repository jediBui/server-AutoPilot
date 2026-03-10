#!/bin/bash
# TARS: Keeping it simple. Almost too simple.

# 1. Get the tools
sudo apt update
sudo apt install -y software-properties-common ansible git

# 2. Run the plan
if [ -f "main.yml" ]; then
    ansible-playbook main.yml
else
    echo "TARS: I can't find main.yml. Did you leave it in the fourth dimension?"
fi
