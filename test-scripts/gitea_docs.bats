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

@test "GITEA_GUIDE.md no longer uses the outdated vault_gitea_db_password variable name" {
  # Regression guard: the variable name documented for both the Ansible
  # Vault and runtime env-var secret-management methods was renamed from
  # 'vault_gitea_db_password' to 'gitea_db_password'. Ensure the stale name
  # does not silently reappear.
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

@test "GITEA_GUIDE.md is wrapped in Jekyll {% raw %}/{% endraw %} tags" {
  # Regression guard: the guide contains Ansible/Jinja2 double-curly-brace
  # syntax (e.g. "{{ lookup(...) }}") that Jekyll's Liquid engine would
  # otherwise attempt to parse and fail to build on GitHub Pages. The
  # entire document must be wrapped in raw/endraw tags to be treated as
  # literal text.
  first_line="$(head -n 1 "${GUIDE}")"
  last_line="$(tail -n 1 "${GUIDE}")"
  [ "${first_line}" = '{% raw %}' ]
  [ "${last_line}" = '{% endraw %}' ]
}

@test "GITEA_GUIDE.md has exactly one raw/endraw tag pair (no duplicates or stray tags)" {
  raw_count="$(grep -cF -- '{% raw %}' "${GUIDE}")"
  endraw_count="$(grep -cF -- '{% endraw %}' "${GUIDE}")"
  [ "${raw_count}" -eq 1 ]
  [ "${endraw_count}" -eq 1 ]
}

@test "GITEA_GUIDE.md's title immediately follows the opening {% raw %} tag" {
  second_line="$(sed -n '2p' "${GUIDE}")"
  [ "${second_line}" = '# Sovereign Gitea Deployment & Security Operations Guide' ]
}

@test "GITEA_GUIDE.md's Liquid-like Ansible template syntax is enclosed within the raw block" {
  # Confirms the specific Jinja2/Ansible double-curly-brace expression that
  # motivated the raw/endraw wrapping is present and located after the
  # opening tag and before the closing tag.
  raw_line="$(grep -nF -- '{% raw %}' "${GUIDE}" | head -1 | cut -d: -f1)"
  endraw_line="$(grep -nF -- '{% endraw %}' "${GUIDE}" | head -1 | cut -d: -f1)"
  liquid_line="$(grep -nF -- "{{ lookup('ansible.builtin.env', 'GITEA_DB_PASSWORD')" "${GUIDE}" | head -1 | cut -d: -f1)"
  [ -n "${liquid_line}" ]
  [ "${liquid_line}" -gt "${raw_line}" ]
  [ "${liquid_line}" -lt "${endraw_line}" ]
}

@test "GITEA_GUIDE.md no longer has a markdownlint-disable comment preceding the Jekyll raw tag" {
  # Regression guard: previously the file began with
  # '<!-- markdownlint-disable MD041 -->{% raw %}' on line 1. That HTML
  # comment prefix was removed so the very first line is the bare
  # '{% raw %}' tag.
  run grep -F -- '<!-- markdownlint-disable MD041 -->{% raw %}' "${GUIDE}"
  [ "${status}" -ne 0 ]
  first_line="$(head -n 1 "${GUIDE}")"
  [ "${first_line}" = '{% raw %}' ]
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
  # Cross-check regression guard: the clone URL and the cd-into-directory
  # command must reference the same repository, regardless of which of the
  # two accepted repository names (podman-elastic-stack-ai or
  # podman-elastic-stack) is currently documented.
  local clone_line cd_line repo_name cd_dir
  clone_line="$(grep -E -- 'git clone https://github.com/[^[:space:]]+\.git' "${GUIDE}" | head -1)"
  cd_line="$(grep -E -- '^cd (podman-elastic-stack-ai|podman-elastic-stack)$' "${GUIDE}" | head -1)"
  [ -n "${clone_line}" ]
  [ -n "${cd_line}" ]
  repo_name="$(echo "${clone_line}" | sed -E 's#.*/([^/]+)\.git$#\1#')"
  cd_dir="$(echo "${cd_line}" | sed -E 's/^cd //')"
  [ "${repo_name}" = "${cd_dir}" ]
}

@test "GITEA_GUIDE.md's git clone command does not reference an unrelated or malformed repository URL" {
  run grep -q -E -- 'git clone https://github.com/(linuxmalaysia/podman-elastic-stack-ai|HarisfazillahJamel/podman-elastic-stack)\.git' "${GUIDE}"
  [ "${status}" -eq 0 ]
  run grep -q -F -- 'git clone https://github.com/some-other-org/unrelated-repo.git' "${GUIDE}"
  [ "${status}" -ne 0 ]
}

@test "GITEA_GUIDE.md's Clone the Repository section appears before Enable User Linger and Verify Podman sections" {
  local clone_line linger_line verify_line
  clone_line="$(grep -n -F -- '### Clone the Repository' "${GUIDE}" | head -1 | cut -d: -f1)"
  linger_line="$(grep -n -F -- '### Enable User Linger' "${GUIDE}" | head -1 | cut -d: -f1)"
  verify_line="$(grep -n -F -- '### Verify Podman & Podman Compose' "${GUIDE}" | head -1 | cut -d: -f1)"
  [ -n "${clone_line}" ]
  [ -n "${linger_line}" ]
  [ -n "${verify_line}" ]
  [ "${clone_line}" -lt "${linger_line}" ]
  [ "${linger_line}" -lt "${verify_line}" ]
}

@test "GITEA_GUIDE.md links to the Git Repository section of INSTALL.md for further cloning details" {
  grep -qF -- '[Git Repository guide in INSTALL.md](INSTALL.md#git-repository)' "${GUIDE}"
}

@test "GITEA_GUIDE.md's INSTALL.md#git-repository anchor target actually exists in INSTALL.md" {
  # Cross-file regression guard: ensures the link added to GITEA_GUIDE.md
  # points at a heading that genuinely exists in INSTALL.md, so the anchor
  # does not silently go stale if INSTALL.md's headings are ever renamed.
  local install_doc="${REPO_ROOT}/docs/INSTALL.md"
  [ -f "${install_doc}" ]
  grep -qE -- '^#+[[:space:]]+Git Repository[[:space:]]*$' "${install_doc}"
}

@test "GITEA_GUIDE.md links to the main Playbooks Guide for Ansible playbook details" {
  grep -qF -- 'please refer to the main [Playbooks Guide](PLAYBOOKS.md)' "${GUIDE}"
}

@test "GITEA_GUIDE.md's PLAYBOOKS.md link target file exists in docs/" {
  [ -f "${REPO_ROOT}/docs/PLAYBOOKS.md" ]
}

@test "GITEA_GUIDE.md's Playbooks Guide reference appears within the Automated Ansible Deployment section" {
  local section_line playbooks_ref_line next_section_line
  section_line="$(grep -n -F -- '## 2. Option A: Automated Ansible Deployment (Recommended)' "${GUIDE}" | head -1 | cut -d: -f1)"
  playbooks_ref_line="$(grep -n -F -- '[Playbooks Guide](PLAYBOOKS.md)' "${GUIDE}" | head -1 | cut -d: -f1)"
  next_section_line="$(grep -n -F -- '## 3. Option B: Pure Command-Line Deployment (Manual)' "${GUIDE}" | head -1 | cut -d: -f1)"
  [ -n "${playbooks_ref_line}" ]
  [ "${playbooks_ref_line}" -gt "${section_line}" ]
  [ "${playbooks_ref_line}" -lt "${next_section_line}" ]
}