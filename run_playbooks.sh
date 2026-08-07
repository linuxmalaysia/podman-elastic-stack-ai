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

echo "--- Running Elastic Stack 9.4.4 setup using Ansible ---"
ansible-playbook -i localhost, -c local "${ANSIBLE_DIR}/main.yml" "$@"
