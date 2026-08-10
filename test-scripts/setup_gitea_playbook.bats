#!/usr/bin/env bats
#
# Tests for ansible/setup_gitea.yml, the rootless Podman + Postgres Gitea
# deployment playbook. Since ansible-playbook is not guaranteed to be
# available in every environment, "true" playbook execution tests (syntax
# check, dry-run) are skipped when the binary is missing, mirroring the
# convention already used in test-scripts/setup_step1_install.bats. The
# remaining tests are pure text/structure regression guards (via grep/awk)
# plus a couple of fully standalone functional tests that exercise the
# exact shell pipelines embedded in the playbook without requiring Ansible
# itself, so they still provide real coverage in minimal environments.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
PLAYBOOK="${REPO_ROOT}/ansible/setup_gitea.yml"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "ansible/setup_gitea.yml exists and is readable" {
  [ -f "${PLAYBOOK}" ]
  [ -r "${PLAYBOOK}" ]
}

@test "ansible/setup_gitea.yml: syntax validation check" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  run ansible-playbook --syntax-check "${PLAYBOOK}"
  [ "${status}" -eq 0 ]
}

@test "ansible/setup_gitea.yml declares the expected play name and defaults to localhost" {
  grep -qF -- '- name: Deploy Sovereign Gitea Rootless Stack' "${PLAYBOOK}"
  grep -qF -- "hosts: \"{{ target_hosts | default('localhost') }}\"" "${PLAYBOOK}"
}

@test "ansible/setup_gitea.yml uses local connection when targeting localhost" {
  grep -qF -- "connection: \"{{ 'local' if (target_hosts | default('localhost') == 'localhost') else ansible_connection | default('ssh') }}\"" "${PLAYBOOK}"
}

@test "ansible/setup_gitea.yml vars block declares all expected variables, in order" {
  # Guards against variables being silently renamed, reordered, or dropped.
  extracted="$(awk '
    /^  vars:$/ {capture=1; next}
    /^  tasks:$/ {exit}
    capture {print}
  ' "${PLAYBOOK}")"

  var_names="$(echo "${extracted}" | grep -oE '^    [a-z_][a-z0-9_]*:' | sed -E 's/^    //; s/:$//' | tr '\n' ' ')"

  expected="gitea_db_user gitea_db_name gitea_db_password gitea_container_name_db gitea_container_name_app gitea_pod_name gitea_http_port gitea_ssh_port gitea_version gitea_domain gitea_root_url gitea_credentials_file "

  [ "${var_names}" = "${expected}" ]
}

@test "ansible/setup_gitea.yml pins the Gitea image version to 1.26.1" {
  grep -qF -- 'gitea_version: "1.26.1"' "${PLAYBOOK}"
  grep -qF -- 'docker.io/gitea/gitea:{{ gitea_version }}' "${PLAYBOOK}"
}

@test "ansible/setup_gitea.yml exposes the documented HTTP (3000) and SSH (2222) ports" {
  grep -qF -- 'gitea_http_port: "3000"' "${PLAYBOOK}"
  grep -qF -- 'gitea_ssh_port: "2222"' "${PLAYBOOK}"
  grep -qF -- '--publish {{ gitea_http_port }}:3000' "${PLAYBOOK}"
  grep -qF -- '--publish {{ gitea_ssh_port }}:22' "${PLAYBOOK}"
}

@test "ansible/setup_gitea.yml default gitea_db_password is blank (so a strong one gets generated)" {
  grep -qF -- 'gitea_db_password: "" # Randomly generated if blank' "${PLAYBOOK}"
}

@test "ansible/setup_gitea.yml credentials file path is derived from the repo root's elk-wolfi directory" {
  grep -qF -- 'gitea_credentials_file: "{{ playbook_dir | dirname }}/elk-wolfi/gitea_credentials.txt"' "${PLAYBOOK}"
}

@test "ansible/setup_gitea.yml declares all eight documented deployment steps, in order" {
  step_names=(
    'Step 1 - Check and Install Podman and Podman Compose'
    'Step 1.5 - Verify Podman and Compose are available'
    'Step 2 - Enable User Linger'
    'Step 3 - Securely Manage Passwords'
    'Step 4 - Create Rootless Podman Pod'
    'Step 5 - Create Rootless Volumes'
    'Step 6 - Deploy Postgres Database Container'
    'Step 7 - Deploy Gitea Application Container'
    'Step 8 - Systemd Integration'
  )
  local prev_line=0
  for step in "${step_names[@]}"; do
    line="$(grep -n -F "${step}" "${PLAYBOOK}" | head -1 | cut -d: -f1)"
    [ -n "${line}" ]
    [ "${line}" -gt "${prev_line}" ]
    prev_line="${line}"
  done
}

@test "ansible/setup_gitea.yml supports both Debian/Ubuntu (apt) and RedHat/CentOS (dnf) package installation" {
  grep -qF -- "when:" "${PLAYBOOK}"
  grep -qF -- "ansible_os_family == 'Debian'" "${PLAYBOOK}"
  grep -qF -- "ansible_os_family == 'RedHat'" "${PLAYBOOK}"
  grep -qF -- 'Install podman and podman-compose via apt' "${PLAYBOOK}"
  grep -qF -- 'Install podman and podman-compose via dnf' "${PLAYBOOK}"
}

@test "ansible/setup_gitea.yml generates a 24-character alphanumeric password when none is provided" {
  grep -qF -- "lookup('ansible.builtin.password', '/dev/null chars=ascii_letters,digits length=24')" "${PLAYBOOK}"
}

@test "ansible/setup_gitea.yml writes generated credentials with 0600 permissions" {
  grep -qF -- 'mode: "0600"' "${PLAYBOOK}"
  # The 0600 mode must belong to the credentials file write task, not an
  # unrelated task; check they appear within a few lines of each other.
  copy_line="$(grep -n -F 'dest: "{{ gitea_credentials_file }}"' "${PLAYBOOK}" | head -1 | cut -d: -f1)"
  mode_line="$(grep -n -F 'mode: "0600"' "${PLAYBOOK}" | head -1 | cut -d: -f1)"
  [ -n "${copy_line}" ]
  [ -n "${mode_line}" ]
  diff=$((mode_line - copy_line))
  [ "${diff}" -ge 0 ]
  [ "${diff}" -le 10 ]
}

@test "ansible/setup_gitea.yml marks every password-related task with no_log: true" {
  # Regression guard: any task whose name or content clearly handles the
  # plaintext DB/Gitea password must never leak it into Ansible's logs.
  password_task_names=(
    'Read existing Gitea password if file exists'
    'Set password from file if found'
    'Generate random secure password'
    'Set final password'
    'Write Gitea credentials to file with 0600 permissions'
  )
  for task in "${password_task_names[@]}"; do
    task_line="$(grep -n -F "name: ${task}" "${PLAYBOOK}" | head -1 | cut -d: -f1)"
    [ -n "${task_line}" ]
    # no_log should appear within the following 15 lines (i.e. still part of
    # the same task block) after the task's name.
    context="$(sed -n "${task_line},$((task_line + 15))p" "${PLAYBOOK}")"
    [[ "${context}" == *"no_log: true"* ]]
  done
}

@test "ansible/setup_gitea.yml marks container-run commands (which embed the password) with no_log: true" {
  for task in 'Run Postgres container inside the pod' 'Run Gitea container inside the pod'; do
    task_line="$(grep -n -F "name: ${task}" "${PLAYBOOK}" | head -1 | cut -d: -f1)"
    [ -n "${task_line}" ]
    context="$(sed -n "${task_line},$((task_line + 20))p" "${PLAYBOOK}")"
    [[ "${context}" == *"no_log: true"* ]]
  done
}

@test "ansible/setup_gitea.yml pod/volume/container creation tasks are guarded to be idempotent" {
  # Each "create" step must first check for existence and only run the
  # create/deploy command when the resource is not already present.
  grep -qF -- 'podman pod exists "{{ gitea_pod_name }}"' "${PLAYBOOK}"
  grep -qF -- 'when: gitea_pod_check.rc != 0' "${PLAYBOOK}"
  grep -qF -- 'podman container exists "{{ gitea_container_name_db }}"' "${PLAYBOOK}"
  grep -qF -- 'when: gitea_db_check.rc != 0' "${PLAYBOOK}"
  grep -qF -- 'podman container exists "{{ gitea_container_name_app }}"' "${PLAYBOOK}"
  grep -qF -- 'when: gitea_app_check.rc != 0' "${PLAYBOOK}"
}

@test "ansible/setup_gitea.yml Postgres container uses the same credentials as the Gitea app container" {
  grep -qF -- '--env POSTGRES_USER={{ gitea_db_user }}' "${PLAYBOOK}"
  grep -qF -- '--env POSTGRES_PASSWORD={{ final_gitea_password }}' "${PLAYBOOK}"
  grep -qF -- '--env GITEA__database__USER={{ gitea_db_user }}' "${PLAYBOOK}"
  grep -qF -- '--env GITEA__database__PASSWD={{ final_gitea_password }}' "${PLAYBOOK}"
}

@test "ansible/setup_gitea.yml Gitea container points its database host at the pod-local Postgres" {
  grep -qF -- '--env GITEA__database__HOST=localhost:5432' "${PLAYBOOK}"
}

@test "ansible/setup_gitea.yml falls back to a raw systemctl --user shell command if the systemd module fails" {
  grep -qF -- "name: \"pod-{{ gitea_pod_name }}.service\"" "${PLAYBOOK}"
  grep -qF -- 'name: Alternative shell reload and enable if scope user fails' "${PLAYBOOK}"
  grep -qF -- 'when: systemd_user_enable.failed | default(false)' "${PLAYBOOK}"
  grep -qF -- 'systemctl --user daemon-reload' "${PLAYBOOK}"
  grep -qF -- 'systemctl --user enable --now "pod-{{ gitea_pod_name }}.service"' "${PLAYBOOK}"
}

# --- Standalone functional test of the embedded password-extraction pipeline ---
#
# The "Read existing Gitea password if file exists" task runs:
#   grep "GITEA_DB_PASSWORD:" "<file>" | sed 's/.*GITEA_DB_PASSWORD: //' | tr -d '\n\r '
# This exercises that exact pipeline (extracted verbatim from the playbook)
# against representative credentials-file fixtures, without needing Ansible.

@test "ansible/setup_gitea.yml: password-extraction shell task is present verbatim" {
  grep -qF -- 'grep \"GITEA_DB_PASSWORD:\" \"{{ gitea_credentials_file }}\"' "${PLAYBOOK}"
  grep -qF -- "sed 's/.*GITEA_DB_PASSWORD: //' | tr -d '\n\r '" "${PLAYBOOK}"
}

_run_password_extraction_pipeline() {
  local fixture="$1"
  grep "GITEA_DB_PASSWORD:" "${fixture}" | sed 's/.*GITEA_DB_PASSWORD: //' | tr -d '\n\r '
}

@test "password-extraction pipeline correctly parses a well-formed credentials file" {
  fixture="${TEST_TMPDIR}/creds.txt"
  cat > "${fixture}" <<'EOF'
# Generated Gitea Credentials
# Keep this file secure and NEVER commit it to git!
GITEA_DB_USER: gitea
GITEA_DB_NAME: gitea
GITEA_DB_PASSWORD: Sup3rSecretPass123
EOF
  result="$(_run_password_extraction_pipeline "${fixture}")"
  [ "${result}" = "Sup3rSecretPass123" ]
}

@test "password-extraction pipeline strips surrounding whitespace and the trailing newline" {
  fixture="${TEST_TMPDIR}/creds_whitespace.txt"
  printf 'GITEA_DB_PASSWORD:   Sp4ceyPassword   \n' > "${fixture}"
  result="$(_run_password_extraction_pipeline "${fixture}")"
  [ "${result}" = "Sp4ceyPassword" ]
}

@test "password-extraction pipeline returns empty output when the field is absent" {
  fixture="${TEST_TMPDIR}/creds_missing.txt"
  cat > "${fixture}" <<'EOF'
GITEA_DB_USER: gitea
GITEA_DB_NAME: gitea
EOF
  result="$(_run_password_extraction_pipeline "${fixture}" || true)"
  [ -z "${result}" ]
}

@test "password-extraction pipeline does not fail the pipeline (via failed_when: false semantics) on a missing file" {
  fixture="${TEST_TMPDIR}/does-not-exist.txt"
  run bash -c "grep \"GITEA_DB_PASSWORD:\" \"${fixture}\" 2>/dev/null | sed 's/.*GITEA_DB_PASSWORD: //' | tr -d '\n\r '"
  # grep exits non-zero for a missing file, but the playbook task sets
  # failed_when: false, so callers must not rely on this pipeline's exit
  # status alone; confirm it produces no password output either way.
  [ -z "${output}" ]
}