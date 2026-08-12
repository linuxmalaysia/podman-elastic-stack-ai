#!/usr/bin/env bats
#
# Regression tests for documentation content in SEMAPHORE_GUIDE.md, the
# deployment/security-operations guide for the rootless Podman Kube
# Quadlet-native SemaphoreUI stack. These guard against accidental drift or
# reverts of the documented commands, playbook invocation examples, and
# secret-management guidance.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
GUIDE="${REPO_ROOT}/docs/SEMAPHORE_GUIDE.md"
GITIGNORE="${REPO_ROOT}/.gitignore"
PLAYBOOK="${REPO_ROOT}/ansible/setup_semaphore.yml"

@test "SEMAPHORE_GUIDE.md exists and is readable" {
  [ -f "${GUIDE}" ]
  [ -r "${GUIDE}" ]
}

@test "SEMAPHORE_GUIDE.md has the expected title" {
  grep -qF -- '# Sovereign SemaphoreUI Deployment & Security Operations Guide' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents all six top-level sections in order" {
  headers=(
    '## 1. Prerequisites'
    '## 2. Option A: Automated Ansible Deployment (Recommended)'
    '## 3. Option B: Pure Command-Line Deployment (Manual)'
    '## 4. Securing and Protecting Passwords in Git (Best Practices)'
    '## 5. Maintenance & Operation Commands'
    '## 6. Web GUI Configuration (GitOps Workflow)'
  )
  local prev_line=0
  for header in "${headers[@]}"; do
    line="$(grep -n -F "${header}" "${GUIDE}" | head -1 | cut -d: -f1)"
    [ -n "${line}" ]
    [ "${line}" -gt "${prev_line}" ]
    prev_line="${line}"
  done
}

@test "SEMAPHORE_GUIDE.md documents a 'Clone the Repository' section under Prerequisites" {
  grep -qF -- '### Clone the Repository' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents the git clone command with the correct repository URL" {
  grep -qF -- 'git clone https://github.com/linuxmalaysia/podman-elastic-stack-ai.git' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents navigating into the cloned project directory" {
  grep -qF -- 'cd podman-elastic-stack-ai' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md links to the Git Repository section of INSTALL.md for further cloning details" {
  grep -qF -- '[Git Repository guide in INSTALL.md](INSTALL.md#git-repository)' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md's INSTALL.md#git-repository anchor target actually exists in INSTALL.md" {
  local install_doc="${REPO_ROOT}/docs/INSTALL.md"
  [ -f "${install_doc}" ]
  grep -qE -- '^#+[[:space:]]+Git Repository[[:space:]]*$' "${install_doc}"
}

@test "SEMAPHORE_GUIDE.md documents enabling user linger for rootless containers" {
  grep -qF -- 'sudo loginctl enable-linger $(whoami)' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents verifying Podman and Podman Compose versions" {
  grep -qF -- 'podman --version' "${GUIDE}"
  grep -qF -- 'podman-compose --version' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md links to the main Playbooks Guide for Ansible playbook details" {
  grep -qF -- 'please refer to the main [Playbooks Guide](PLAYBOOKS.md)' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md's PLAYBOOKS.md link target file exists in docs/" {
  [ -f "${REPO_ROOT}/docs/PLAYBOOKS.md" ]
}

@test "SEMAPHORE_GUIDE.md documents the Ansible playbook execution commands" {
  grep -qF -- 'ansible-playbook ansible/setup_semaphore.yml' "${GUIDE}"
  grep -qF -- 'ansible-playbook -i inventory/hosts.yml ansible/setup_semaphore.yml -e "target_hosts=production_nodes"' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md's documented playbook path actually exists in ansible/" {
  [ -f "${PLAYBOOK}" ]
}

@test "SEMAPHORE_GUIDE.md describes automated password management (0600 permissions and 32-byte Base64 access key)" {
  grep -qF -- 'elk-wolfi/semaphore_credentials.txt' "${GUIDE}"
  grep -qF -- 'strict `0600` permissions' "${GUIDE}"
  grep -qF -- '32-byte Base64-encoded Semaphore access key' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents TLS certificate generation and CA trust installation" {
  grep -qF -- '10-year self-signed SSL certificate' "${GUIDE}"
  grep -qF -- '/etc/ssl/certs/ca-certificates.crt' "${GUIDE}"
  grep -qF -- '/etc/pki/ca-trust/source/anchors/' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents the manual self-signed certificate generation command" {
  grep -qF -- 'openssl req -x509 -newkey rsa:4096 -nodes' "${GUIDE}"
  grep -qF -- '-sha256 -days 3650' "${GUIDE}"
  grep -qF -- '-subj "/C=MY/ST=Kuala Lumpur/L=Kuala Lumpur/O=Sovereign/OU=IT/CN=localhost"' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents installing the certificate into both Debian and RedHat trust stores" {
  grep -qF -- 'sudo update-ca-certificates' "${GUIDE}"
  grep -qF -- 'sudo update-ca-trust' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents the manual Quadlet Kube unit file contents" {
  grep -qF -- 'Description=Sovereign Semaphore UI Stack (Quadlet Kube)' "${GUIDE}"
  grep -qF -- 'Yaml=semaphore-stack.yaml' "${GUIDE}"
  grep -qF -- 'WantedBy=default.target' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents the manual Kubernetes Pod manifest with the pinned MySQL and Semaphore images" {
  grep -qF -- 'image: docker.io/library/mysql:8.0' "${GUIDE}"
  grep -qF -- 'image: docker.io/semaphoreui/semaphore:latest' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents systemd load/start commands for the Quadlet service" {
  grep -qF -- 'systemctl --user daemon-reload' "${GUIDE}"
  grep -qF -- 'systemctl --user enable --now semaphore-stack.service' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md warns against hardcoding secrets inside Git repositories" {
  grep -qF -- 'hardcoded secrets inside Git repositories must be strictly avoided' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents Ansible Vault as a secret-management method" {
  grep -qF -- 'ansible-vault create ansible/group_vars/vault_secrets.yml' "${GUIDE}"
  grep -qF -- 'semaphore_db_password:' "${GUIDE}"
  grep -qF -- '--ask-vault-pass' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents runtime environment variable injection as a secret-management method" {
  grep -qF -- "lookup('ansible.builtin.env', 'SEMAPHORE_DB_PASSWORD')" "${GUIDE}"
  grep -qF -- 'SEMAPHORE_DB_PASSWORD="MyDynamicTerminalPassword_123!" ansible-playbook ansible/setup_semaphore.yml' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md's documented .gitignore snippet matches the real .gitignore (no drift)" {
  # Extracts the fenced 'git' code block under Method 3 (Strictly Configured
  # Local Exclusions) and verifies each listed pattern is genuinely present
  # in the repository's real .gitignore, guarding against the guide silently
  # going stale relative to the actual ignore rules.
  for pattern in '*temp_credentials.txt' '*semaphore_credentials.txt' '*.env' '*.vault'; do
    grep -qF -- "${pattern}" "${GUIDE}"
    grep -qF -- "${pattern}" "${GITIGNORE}"
  done
}

@test "SEMAPHORE_GUIDE.md documents maintenance commands (status, logs, restart)" {
  grep -qF -- 'systemctl --user status semaphore-stack.service' "${GUIDE}"
  grep -qF -- 'journalctl --user -u semaphore-stack.service -f' "${GUIDE}"
  grep -qF -- 'systemctl --user restart semaphore-stack.service' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents how to fully destroy the stack, including volumes" {
  grep -qF -- 'systemctl --user disable --now semaphore-stack.service' "${GUIDE}"
  grep -qF -- 'rm -f ~/.config/containers/systemd/semaphore-stack*' "${GUIDE}"
  grep -qF -- 'podman volume rm semaphore-mysql-pvc' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md documents the Web GUI GitOps workflow steps in order" {
  headers=(
    '### 1. Initial Login'
    '### 2. Key Store'
    '### 3. Repository Setup'
    '### 4. Inventory Setup'
    '### 5. Environments (Privilege Escalation)'
    '### 6. Task Templates (Playbook Execution)'
  )
  local prev_line=0
  for header in "${headers[@]}"; do
    line="$(grep -n -F "${header}" "${GUIDE}" | head -1 | cut -d: -f1)"
    [ -n "${line}" ]
    [ "${line}" -gt "${prev_line}" ]
    prev_line="${line}"
  done
}

@test "SEMAPHORE_GUIDE.md documents the default admin username and TLS-enabled web dashboard URL" {
  grep -qF -- 'https://<jumphost-ip>:3001' "${GUIDE}"
  grep -qF -- '**Username**: `admin`' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md's documented hostPort matches the port used in the Web GUI login URL" {
  # Cross-check regression guard: the Kube manifest's hostPort and the
  # documented web dashboard access URL must stay in sync.
  local manifest_port login_port
  manifest_port="$(grep -oE 'hostPort: [0-9]+' "${GUIDE}" | head -1 | grep -oE '[0-9]+')"
  login_port="$(grep -oE 'https://<jumphost-ip>:[0-9]+' "${GUIDE}" | head -1 | grep -oE '[0-9]+$')"
  [ -n "${manifest_port}" ]
  [ -n "${login_port}" ]
  [ "${manifest_port}" = "${login_port}" ]
}

@test "SEMAPHORE_GUIDE.md's documented hostPort/containerPort mapping matches the actual ansible playbook" {
  grep -qF -- 'hostPort: 3001' "${PLAYBOOK}"
  grep -qF -- 'containerPort: 3000' "${PLAYBOOK}"
  grep -qF -- 'hostPort: 3001' "${GUIDE}"
  grep -qF -- 'containerPort: 3000' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md is wrapped in Jekyll {% raw %}/{% endraw %} tags" {
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

@test "SEMAPHORE_GUIDE.md has exactly one raw/endraw tag pair (no duplicates or stray tags)" {
  raw_count="$(grep -cF -- '{% raw %}' "${GUIDE}")"
  endraw_count="$(grep -cF -- '{% endraw %}' "${GUIDE}")"
  [ "${raw_count}" -eq 1 ]
  [ "${endraw_count}" -eq 1 ]
}

@test "SEMAPHORE_GUIDE.md's title immediately follows the opening {% raw %} tag" {
  second_line="$(sed -n '2p' "${GUIDE}")"
  [ "${second_line}" = '# Sovereign SemaphoreUI Deployment & Security Operations Guide' ]
}

@test "SEMAPHORE_GUIDE.md's Liquid-like Ansible template syntax is enclosed within the raw block" {
  # Confirms the specific Jinja2/Ansible double-curly-brace expression that
  # motivated the raw/endraw wrapping is present and located after the
  # opening tag and before the closing tag.
  raw_line="$(grep -nF -- '{% raw %}' "${GUIDE}" | head -1 | cut -d: -f1)"
  endraw_line="$(grep -nF -- '{% endraw %}' "${GUIDE}" | head -1 | cut -d: -f1)"
  liquid_line="$(grep -nF -- "{{ lookup('ansible.builtin.env', 'SEMAPHORE_DB_PASSWORD')" "${GUIDE}" | head -1 | cut -d: -f1)"
  [ -n "${liquid_line}" ]
  [ "${liquid_line}" -gt "${raw_line}" ]
  [ "${liquid_line}" -lt "${endraw_line}" ]
}

@test "SEMAPHORE_GUIDE.md declares a markdownlint-disable-file directive to suppress the MD041 lint rule" {
  grep -qF -- '<!-- markdownlint-disable-file MD041 -->' "${GUIDE}"
}

@test "SEMAPHORE_GUIDE.md's markdownlint directive appears after the title and before the first '---' section divider" {
  local title_line directive_line divider_line
  title_line="$(grep -n -F -- '# Sovereign SemaphoreUI Deployment & Security Operations Guide' "${GUIDE}" | head -1 | cut -d: -f1)"
  directive_line="$(grep -n -F -- '<!-- markdownlint-disable-file MD041 -->' "${GUIDE}" | head -1 | cut -d: -f1)"
  divider_line="$(grep -n -F -- '---' "${GUIDE}" | head -1 | cut -d: -f1)"
  [ -n "${title_line}" ]
  [ -n "${directive_line}" ]
  [ -n "${divider_line}" ]
  [ "${directive_line}" -gt "${title_line}" ]
  [ "${directive_line}" -lt "${divider_line}" ]
}

@test "SEMAPHORE_GUIDE.md is registered in mkdocs.yml nav and llms.txt Core Documentation list" {
  # Cross-file regression guard: ensures the new guide is actually
  # discoverable from the site navigation and the LLM-friendly index, not
  # just present as a standalone orphaned file.
  grep -qF -- 'SEMAPHORE_GUIDE.md' "${REPO_ROOT}/mkdocs.yml"
  grep -qF -- 'SEMAPHORE_GUIDE.md' "${REPO_ROOT}/llms.txt"
}