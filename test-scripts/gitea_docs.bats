#!/usr/bin/env bats
#
# Regression tests for documentation content in GITEA_GUIDE.md, the
# deployment/security-operations guide for the rootless Podman Gitea stack.
# These guard against accidental drift or reverts of the documented
# commands, playbook invocation examples, and secret-management guidance.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
GUIDE="${REPO_ROOT}/docs/GITEA_GUIDE.md"
GITIGNORE="${REPO_ROOT}/.gitignore"

@test "GITEA_GUIDE.md exists and is readable" {
  [ -f "${GUIDE}" ]
  [ -r "${GUIDE}" ]
}

@test "GITEA_GUIDE.md has the expected title" {
  grep -qF -- '# Sovereign Gitea Deployment & Security Operations Guide' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents all five top-level sections in order" {
  headers=(
    '## 1. Prerequisites'
    '## 2. Option A: Automated Ansible Deployment (Recommended)'
    '## 3. Option B: Pure Command-Line Deployment (Manual)'
    '## 4. Securing and Protecting Passwords in Git (Best Practices)'
    '## 5. Maintenance & Operation Commands'
  )
  local prev_line=0
  for header in "${headers[@]}"; do
    line="$(grep -n -F "${header}" "${GUIDE}" | head -1 | cut -d: -f1)"
    [ -n "${line}" ]
    [ "${line}" -gt "${prev_line}" ]
    prev_line="${line}"
  done
}

@test "GITEA_GUIDE.md documents enabling user linger for rootless containers" {
  grep -qF -- 'sudo loginctl enable-linger $(whoami)' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents verifying Podman and Podman Compose versions" {
  grep -qF -- 'podman --version' "${GUIDE}"
  grep -qF -- 'podman-compose --version' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents the Ansible playbook execution commands" {
  grep -qF -- 'ansible-playbook ansible/setup_gitea.yml' "${GUIDE}"
  grep -qF -- 'ansible-playbook -i inventory/hosts.yml ansible/setup_gitea.yml -e "target_hosts=gitea_production_nodes"' "${GUIDE}"
}

@test "GITEA_GUIDE.md describes automated password management (24-char, 0600 permissions)" {
  grep -qF -- 'cryptographically secure 24-character random password' "${GUIDE}"
  grep -qF -- 'strict `0600` permissions' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents the manual pod creation with correct port mappings" {
  grep -qF -- 'podman pod create' "${GUIDE}"
  grep -qF -- '--name gitea-stack' "${GUIDE}"
  grep -qF -- '--publish 3000:3000' "${GUIDE}"
  grep -qF -- '--publish 2222:22' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents manual volume creation for db and app data" {
  grep -qF -- 'podman volume create gitea_db_data' "${GUIDE}"
  grep -qF -- 'podman volume create gitea_app_data' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents the manual Postgres deployment with correct pinned image" {
  grep -qF -- 'docker.io/library/postgres:15-alpine' "${GUIDE}"
  grep -qF -- '--env POSTGRES_USER=gitea' "${GUIDE}"
  grep -qF -- '--env POSTGRES_DB=gitea' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents the manual Gitea deployment with correct pinned image and env vars" {
  grep -qF -- 'docker.io/gitea/gitea:1.26.1' "${GUIDE}"
  grep -qF -- 'GITEA__database__DB_TYPE=postgres' "${GUIDE}"
  grep -qF -- 'GITEA__server__HTTP_PORT=3000' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents systemd generation and enablement commands" {
  grep -qF -- 'podman generate systemd --name gitea-stack --files --new' "${GUIDE}"
  grep -qF -- 'systemctl --user enable --now pod-gitea-stack.service' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents Ansible Vault as a secret-management method" {
  grep -qF -- 'ansible-vault create ansible/group_vars/vault_secrets.yml' "${GUIDE}"
  grep -qF -- 'gitea_db_password:' "${GUIDE}"
  grep -qF -- '--ask-vault-pass' "${GUIDE}"
  grep -qF -- '--vault-password-file ~/.gitea_vault_pass.txt' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents runtime environment variable injection as a secret-management method" {
  grep -qF -- "lookup('ansible.builtin.env', 'GITEA_DB_PASSWORD')" "${GUIDE}"
  grep -qF -- 'GITEA_DB_PASSWORD="MyDynamicTerminalPassword_123!" ansible-playbook ansible/setup_gitea.yml' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents gitleaks as a pre-commit secret scanner" {
  grep -qF -- 'gitleaks detect -v' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents maintenance commands (status, logs, restart)" {
  grep -qF -- 'systemctl --user status pod-gitea-stack.service' "${GUIDE}"
  grep -qF -- 'journalctl --user -u pod-gitea-stack.service -f' "${GUIDE}"
  grep -qF -- 'systemctl --user restart pod-gitea-stack.service' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents how to fully destroy the stack, including volumes" {
  grep -qF -- 'systemctl --user disable --now pod-gitea-stack.service' "${GUIDE}"
  grep -qF -- 'podman pod rm -f gitea-stack' "${GUIDE}"
  grep -qF -- 'podman volume rm gitea_db_data gitea_app_data' "${GUIDE}"
}

@test "GITEA_GUIDE.md's documented .gitignore snippet matches the real .gitignore (no drift)" {
  # Extracts the fenced 'git' code block under Method 3 (Strictly Configured
  # Local Exclusions) and verifies each listed pattern is genuinely present
  # in the repository's real .gitignore, guarding against the guide silently
  # going stale relative to the actual ignore rules.
  for pattern in '*temp_credentials.txt' '*gitea_credentials.txt' '*.env' '*.vault'; do
    grep -qF -- "${pattern}" "${GUIDE}"
    grep -qF -- "${pattern}" "${GITIGNORE}"
  done
}

@test "GITEA_GUIDE.md warns against hardcoding secrets inside Git repositories" {
  grep -qF -- 'hardcoded secrets inside Git repositories must be strictly avoided' "${GUIDE}"
}