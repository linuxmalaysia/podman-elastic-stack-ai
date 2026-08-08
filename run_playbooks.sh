#!/usr/bin/env bash
# Bash script calling all Ansible playbooks via the primary playbook main.yml
# GNU GENERAL PUBLIC LICENSE Version 3
# Harisfazillah Jamel and Google Gemini
# 20250402

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"

# Ensure ansible-playbook is installed
if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Error: ansible-playbook is not installed."
  echo "Please install Ansible before running this script."
  exit 1
fi

# Check if an inventory option is already provided in the arguments
HAS_INVENTORY=false
for arg in "$@"; do
  if [[ "$arg" == "-i" || "$arg" == "--inventory" || "$arg" == "--inventory-file" ]]; then
    HAS_INVENTORY=true
    break
  fi
done

echo "--- Running Elastic Stack 9.4.4 setup using Ansible ---"
if [ "$HAS_INVENTORY" = true ]; then
  ansible-playbook "${ANSIBLE_DIR}/main.yml" "$@"
else
  ansible-playbook -i "${SCRIPT_DIR}/inventory/hosts.yml" "${ANSIBLE_DIR}/main.yml" "$@"
fi
