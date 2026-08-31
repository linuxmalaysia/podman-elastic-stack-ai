#!/usr/bin/env bats
#
# Regression tests for documentation content in GITEA_GUIDE.md, the
# deployment/security-operations guide for the rootless Podman Gitea stack.
# These guard against accidental drift or reverts of the documented
# commands, playbook invocation examples, OKF frontmatter, and secret-management guidance.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
GUIDE="${REPO_ROOT}/docs/GITEA_GUIDE.md"
GITIGNORE="${REPO_ROOT}/.gitignore"

@test "GITEA_GUIDE.md exists and is readable" {
  [ -f "${GUIDE}" ]
  [ -r "${GUIDE}" ]
}

@test "GITEA_GUIDE.md opens on line 1 with YAML frontmatter marker and contains OKF v0.2 metadata" {
  first_line="$(head -n 1 "${GUIDE}")"
  [ "${first_line}" = '---' ]

  frontmatter="$(awk 'BEGIN {show=0; count=0} /^---$/ {count++; if(count==1) {show=1; next} if(count==2) {show=0; exit}} show {print}' "${GUIDE}")"
  echo "${frontmatter}" | grep -Fxq 'okf_version: 0.2'
  echo "${frontmatter}" | grep -Fxq 'type: documentation'
  echo "${frontmatter}" | grep -Fxq 'resource: "file:///docs/GITEA_GUIDE.md"'
  echo "${frontmatter}" | grep -q '^topics: \['
}

@test "GITEA_GUIDE.md has the expected title" {
  grep -qF -- '# Sovereign Gitea Deployment & Security Operations Guide' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents all top-level sections in order" {
  headers=(
    '## 1. Overview & Architecture'
    '## 2. Prerequisites'
    '## 3. How-To 1: Pure Command-Line & Quadlet Deployment (Standalone Manual)'
    '## 4. How-To 2: Automated Ansible Playbook Deployment (Recommended)'
    '## 5. Post-Installation Account, Token & Repository Setup (CLI & API)'
    '## 6. Git Remote & Client Access (HTTPS & SSH)'
    '## 7. Securing and Protecting Passwords in Git (Best Practices)'
    '## 8. Maintenance & Operational Troubleshooting Commands'
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

@test "GITEA_GUIDE.md documents HTTPS TLS certificate generation and restrictive key permissions" {
  grep -qF -- 'openssl genrsa -out ~/.config/gitea/certs/gitea.key 2048' "${GUIDE}"
  grep -qF -- 'chmod 0600 ~/.config/gitea/certs/gitea.key' "${GUIDE}"
  grep -qF -- 'chmod 0644 ~/.config/gitea/certs/gitea.crt' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents the Ansible playbook execution commands" {
  grep -qF -- 'ansible-playbook ansible/setup_gitea.yml' "${GUIDE}"
  grep -qF -- 'ansible-playbook -i inventory/hosts.yml ansible/setup_gitea.yml -e "target_hosts=gitea_production_nodes"' "${GUIDE}"
}

@test "GITEA_GUIDE.md describes automated password management (24-char, 0600 permissions)" {
  grep -qF -- '24-character cryptographically secure password' "${GUIDE}"
  grep -qF -- 'strict `0600` permissions' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents manual pod creation with correct port mappings" {
  grep -qF -- 'podman pod create' "${GUIDE}"
  grep -qF -- '--name gitea-stack' "${GUIDE}"
  grep -qF -- '--publish 3000:3000' "${GUIDE}"
  grep -qF -- '--publish 2222:22' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents manual volume creation for db and app data" {
  grep -qF -- 'podman volume create gitea_db_data' "${GUIDE}"
  grep -qF -- 'podman volume create gitea_app_data' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents manual Postgres deployment with correct pinned image" {
  grep -qF -- 'docker.io/library/postgres:15-alpine' "${GUIDE}"
  grep -qF -- 'POSTGRES_USER=gitea' "${GUIDE}"
  grep -qF -- 'POSTGRES_DB=gitea' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents manual Gitea deployment with correct pinned image and env vars" {
  grep -qF -- 'docker.io/gitea/gitea:1.26.1' "${GUIDE}"
  grep -qF -- 'GITEA__database__DB_TYPE=postgres' "${GUIDE}"
  grep -qF -- 'GITEA__server__HTTP_PORT=3000' "${GUIDE}"
  grep -qF -- 'GITEA__security__INSTALL_LOCK=true' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents systemd generation and Quadlet enablement commands" {
  grep -qF -- 'podman generate systemd --name gitea-stack --files --new' "${GUIDE}"
  grep -qF -- 'systemctl --user enable --now pod-gitea-stack.service' "${GUIDE}"
  grep -qF -- 'Description=Gitea GitOps Service (Podman Kube Quadlet)' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents Ansible Vault as a secret-management method" {
  grep -qF -- 'ansible-vault create ansible/group_vars/vault_secrets.yml' "${GUIDE}"
  grep -qF -- 'gitea_db_password:' "${GUIDE}"
  grep -qF -- '--ask-vault-pass' "${GUIDE}"
  grep -qF -- '--vault-password-file ~/.gitea_vault_pass.txt' "${GUIDE}"
}

@test "GITEA_GUIDE.md no longer uses the outdated vault_gitea_db_password variable name" {
  run grep -qF -- 'vault_gitea_db_password:' "${GUIDE}"
  [ "${status}" -ne 0 ]
}

@test "GITEA_GUIDE.md uses gitea_db_password consistently across both the Vault and env-var methods" {
  local count
  count="$(grep -cF -- 'gitea_db_password:' "${GUIDE}")"
  [ "${count}" -ge 2 ]
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
  for pattern in '*temp_credentials.txt' '*gitea_credentials.txt' '*.env' '*.vault'; do
    grep -qF -- "${pattern}" "${GUIDE}"
    grep -qF -- "${pattern}" "${GITIGNORE}"
  done
}

@test "GITEA_GUIDE.md warns against hardcoding secrets inside Git repositories" {
  grep -qF -- 'hardcoded secrets inside Git repositories must be strictly avoided' "${GUIDE}"
}

@test "GITEA_GUIDE.md is properly wrapped in Jekyll {% raw %}/{% endraw %} tags after OKF frontmatter" {
  marker2_line="$(grep -n '^---$' "${GUIDE}" | sed -n '2p' | cut -d: -f1)"
  raw_line="$(grep -nF '{% raw %}' "${GUIDE}" | head -1 | cut -d: -f1)"
  endraw_line="$(grep -nF '{% endraw %}' "${GUIDE}" | head -1 | cut -d: -f1)"

  raw_count="$(grep -oF '{% raw %}' "${GUIDE}" | wc -l)"
  endraw_count="$(grep -oF '{% endraw %}' "${GUIDE}" | wc -l)"
  [ "${raw_count}" -eq 1 ]
  [ "${endraw_count}" -eq 1 ]

  [ -n "${marker2_line}" ]
  [ -n "${raw_line}" ]
  [ -n "${endraw_line}" ]
  [ "${raw_line}" -gt "${marker2_line}" ]
  [ "${endraw_line}" -gt "${raw_line}" ]
}

@test "GITEA_GUIDE.md's title immediately follows the opening {% raw %} tag" {
  raw_line="$(grep -nF '{% raw %}' "${GUIDE}" | head -1 | cut -d: -f1)"
  title_line_num=$((raw_line + 2))
  title_line="$(sed -n "${title_line_num}p" "${GUIDE}")"
  [ "${title_line}" = '# Sovereign Gitea Deployment & Security Operations Guide' ]
}

@test "GITEA_GUIDE.md documents a 'Clone the Repository' section under Prerequisites" {
  grep -qF -- '### Clone the Repository' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents the git clone command with the correct repository URL" {
  grep -q -E 'git clone https://github.com/(linuxmalaysia/podman-elastic-stack-ai|HarisfazillahJamel/podman-elastic-stack)\.git' "${GUIDE}"
}

@test "GITEA_GUIDE.md documents navigating into the cloned project directory" {
  grep -q -E 'cd (podman-elastic-stack-ai|podman-elastic-stack)' "${GUIDE}"
}

@test "GITEA_GUIDE.md's cd directory name matches the repository name in its git clone command" {
  local clone_line cd_line repo_name cd_dir
  clone_line="$(grep -E -- 'git clone https://github.com/[^[:space:]]+\.git' "${GUIDE}" | head -1)"
  cd_line="$(grep -E -- '^cd (podman-elastic-stack-ai|podman-elastic-stack)$' "${GUIDE}" | head -1)"
  [ -n "${clone_line}" ]
  [ -n "${cd_line}" ]
  repo_name="$(echo "${clone_line}" | sed -E 's#.*/([^/]+)\.git$#\1#')"
  cd_dir="$(echo "${cd_line}" | sed -E 's/^cd //')"
  [ "${repo_name}" = "${cd_dir}" ]
}

@test "GITEA_GUIDE.md links to the Git Repository section of INSTALL.md for further cloning details" {
  grep -qF -- '[Git Repository guide in INSTALL.md](INSTALL.md#git-repository)' "${GUIDE}"
}

@test "GITEA_GUIDE.md links to the main Playbooks Guide for Ansible playbook details" {
  grep -qF -- 'please refer to the [Playbooks Guide](PLAYBOOKS.md)' "${GUIDE}" || grep -qF -- 'refer to the [Playbooks Guide](PLAYBOOKS.md)' "${GUIDE}"
}
