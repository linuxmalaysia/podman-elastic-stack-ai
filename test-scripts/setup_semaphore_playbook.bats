#!/usr/bin/env bats
#
# Tests for ansible/setup_semaphore.yml, the Podman Quadlet-native SemaphoreUI
# deployment playbook.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
PLAYBOOK="${REPO_ROOT}/ansible/setup_semaphore.yml"

@test "ansible/setup_semaphore.yml exists and is readable" {
  [ -f "${PLAYBOOK}" ]
  [ -r "${PLAYBOOK}" ]
}

@test "ansible/setup_semaphore.yml: syntax validation check" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  run ansible-playbook --syntax-check "${PLAYBOOK}"
  [ "${status}" -eq 0 ]
}

@test "ansible/setup_semaphore.yml declares the expected play name and defaults to localhost" {
  grep -qF -- '- name: Deploy Sovereign Semaphore Stack' "${PLAYBOOK}"
  grep -qF -- "hosts: \"{{ target_hosts | default('localhost') }}\"" "${PLAYBOOK}"
}

@test "ansible/setup_semaphore.yml uses local connection when targeting localhost" {
  grep -qF -- "connection: \"{{ 'local' if (target_hosts | default('localhost') == 'localhost') else ansible_connection | default('ssh') }}\"" "${PLAYBOOK}"
}

@test "ansible/setup_semaphore.yml vars block declares expected variables" {
  grep -qF "semaphore_db_user:" "${PLAYBOOK}"
  grep -qF "semaphore_db_name:" "${PLAYBOOK}"
  grep -qF "semaphore_db_password:" "${PLAYBOOK}"
  grep -qF "semaphore_admin_password:" "${PLAYBOOK}"
  grep -qF "semaphore_access_key:" "${PLAYBOOK}"
  grep -qF "semaphore_certs_dir:" "${PLAYBOOK}"
  grep -qF "semaphore_credentials_file:" "${PLAYBOOK}"
}

@test "ansible/setup_semaphore.yml exposes the documented host port (3001) mapping to container port (3000)" {
  grep -qF 'hostPort: 3001' "${PLAYBOOK}"
  grep -qF 'containerPort: 3000' "${PLAYBOOK}"
}

@test "ansible/setup_semaphore.yml default passwords/access keys are blank" {
  grep -qF 'semaphore_db_password: "" # Randomly generated if blank' "${PLAYBOOK}"
  grep -qF 'semaphore_admin_password: "" # Randomly generated if blank' "${PLAYBOOK}"
  grep -qF 'semaphore_access_key: "" # Randomly generated if blank' "${PLAYBOOK}"
}

@test "ansible/setup_semaphore.yml credentials file path defaults to user config secrets" {
  grep -qF 'semaphore_credentials_file: "{{ semaphore_credentials_override | default(ansible_env.HOME ~' "${PLAYBOOK}"
  grep -qF '/.config/containers/semaphoreui/secrets/semaphore_credentials.txt' "${PLAYBOOK}"
}

@test "ansible/setup_semaphore.yml declares all expected deployment steps, in order" {
  step_names=(
    'Step 1 - Check and Install Podman'
    'Step 1.5 - Verify Podman is available'
    'Step 1.6 - Check Podman Version is 5 or Newer'
    'Step 2 - Enable User Linger'
    'Step 3 - Securely Manage Passwords'
    'Step 4 - TLS Configuration & Internal CA Trust'
    'Step 5 - Create Kube Quadlet and Kubernetes YAML'
    'Step 6 - Systemd Integration'
  )
  local prev_line=0
  for step in "${step_names[@]}"; do
    line="$(grep -n -F "${step}" "${PLAYBOOK}" | head -1 | cut -d: -f1)"
    [ -n "${line}" ]
    [ "${line}" -gt "${prev_line}" ]
    prev_line="${line}"
  done
}

@test "ansible/setup_semaphore.yml supports both Debian/Ubuntu (apt) and RedHat/CentOS (dnf) package installation" {
  grep -qF -- "ansible_os_family == 'Debian'" "${PLAYBOOK}"
  grep -qF -- "ansible_os_family == 'RedHat'" "${PLAYBOOK}"
  grep -qF -- 'Install podman via apt' "${PLAYBOOK}"
  grep -qF -- 'Install podman via dnf' "${PLAYBOOK}"
}

@test "ansible/setup_semaphore.yml generates a 24-character alphanumeric password for DB/Admin when none is provided" {
  local count
  count="$(grep -c "lookup('ansible.builtin.password', '/dev/null chars=ascii_letters,digits length=24')" "${PLAYBOOK}")"
  [ "${count}" -ge 2 ]
}

@test "ansible/setup_semaphore.yml generates a 32-byte valid Base64 access key when none is provided" {
  grep -qF "openssl rand -base64 32" "${PLAYBOOK}"
}

@test "ansible/setup_semaphore.yml writes generated credentials with 0600 permissions" {
  grep -qF -- 'mode: "0600"' "${PLAYBOOK}"
  copy_line="$(grep -n -F 'dest: "{{ semaphore_credentials_file }}"' "${PLAYBOOK}" | head -1 | cut -d: -f1)"
  mode_line="$(grep -n -F 'mode: "0600"' "${PLAYBOOK}" | head -1 | cut -d: -f1)"
  [ -n "${copy_line}" ]
  [ -n "${mode_line}" ]
  diff=$((mode_line - copy_line))
  [ "${diff}" -ge 0 ]
  [ "${diff}" -le 10 ]
}

@test "ansible/setup_semaphore.yml writes the manifest file with 0600 permissions" {
  manifest_copy_line="$(grep -n -F 'dest: "{{ ansible_env.HOME }}/.config/containers/systemd/semaphore-stack.yaml"' "${PLAYBOOK}" | head -1 | cut -d: -f1)"
  [ -n "${manifest_copy_line}" ]
  context="$(sed -n "${manifest_copy_line},$((manifest_copy_line + 10))p" "${PLAYBOOK}")"
  [[ "${context}" == *'mode: "0600"'* ]]
}

@test "ansible/setup_semaphore.yml marks password-related tasks with no_log: true" {
  password_task_names=(
    'Parse existing Semaphore credentials from slurped content'
    'Set parsed credential facts with precedence and defaults'
    'Generate random secure DB password if missing'
    'Generate random secure Admin password if missing'
    'Generate 32-byte valid Base64 access key if missing'
    'Set final access key from command output if generated'
    'Write Semaphore credentials to file with 0600 permissions'
  )
  for task in "${password_task_names[@]}"; do
    task_line="$(grep -n -F "name: ${task}" "${PLAYBOOK}" | head -1 | cut -d: -f1)"
    [ -n "${task_line}" ]
    context="$(sed -n "${task_line},$((task_line + 15))p" "${PLAYBOOK}")"
    [[ "${context}" == *"no_log: true"* ]]
  done
}

@test "ansible/setup_semaphore.yml marks Kube/YAML files (which embed passwords) with no_log: true" {
  task_line="$(grep -n -F "name: Create Kubernetes YAML manifest file" "${PLAYBOOK}" | head -1 | cut -d: -f1)"
  [ -n "${task_line}" ]
  context="$(sed -n "${task_line},$((task_line + 20))p" "${PLAYBOOK}")"
  [[ "${context}" == *"no_log: true"* ]]
}

@test "ansible/setup_semaphore.yml falls back to a raw systemctl --user shell command if the systemd module fails" {
  grep -qF -- 'name: Alternative shell reload and enable if scope user fails' "${PLAYBOOK}"
  grep -qF -- 'when: systemd_user_enable.failed | default(false)' "${PLAYBOOK}"
  grep -qF -- 'systemctl --user daemon-reload' "${PLAYBOOK}"
  grep -qF -- 'systemctl --user enable --now "semaphore-stack.service"' "${PLAYBOOK}"
}
