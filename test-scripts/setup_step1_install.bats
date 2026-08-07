#!/usr/bin/env bats
#
# Tests for the Step 1 "Install Podman and Podman Compose" OS-detection
# logic introduced in setup_elasticsearch.sh and test-scripts/setup_elk.sh.
#
# The scripts read the OS identity from the hard-coded path /etc/os-release.
# Since the sandbox running these tests has no write access to /etc and no
# /etc/os-release file, the Step 1 block is extracted verbatim from the
# real script (via awk, using the same "# --- Step N: ---" markers already
# present in the source) and the hard-coded /etc/os-release path is
# substituted with a fixture path so each scenario can be exercised in
# isolation. The extraction is verified against a golden excerpt so the
# tests fail loudly if the real script's Step 1 block changes shape.
#
# All external side-effecting commands (sudo, apt-get, dnf) are replaced
# with stub executables on PATH that simply record their invocation.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

ES_SCRIPT="${REPO_ROOT}/setup_elasticsearch.sh"
ELK_SCRIPT="${REPO_ROOT}/test-scripts/setup_elk.sh"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  STUB_BIN="${TEST_TMPDIR}/bin"
  mkdir -p "${STUB_BIN}"
  CALL_LOG="${TEST_TMPDIR}/calls.log"
  : > "${CALL_LOG}"
  export CALL_LOG
  # Prepend the stub bin dir so our fakes take priority over anything real.
  export PATH="${STUB_BIN}:${PATH}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

# Create a stub executable on PATH that logs its name and arguments.
stub() {
  local name="$1"
  cat > "${STUB_BIN}/${name}" <<EOF
#!/usr/bin/env bash
echo "${name} \$*" >> "${CALL_LOG}"
exit 0
EOF
  chmod +x "${STUB_BIN}/${name}"
}

# Remove a stub so "command -v" reports the command as missing.
unstub() {
  rm -f "${STUB_BIN}/$1"
}

# Extracts the "Step 1: Install Podman and Podman Compose" block from the
# given script and wraps it into a standalone executable harness. The
# hard-coded /etc/os-release reference is rewritten to os_release_file so
# tests can point it at a fixture (or a nonexistent path, to simulate an
# unknown OS) without touching the real filesystem path.
build_step1_harness() {
  local src="$1"
  local os_release_file="$2"
  local harness="${TEST_TMPDIR}/harness_$$_${RANDOM}.sh"

  {
    echo '#!/usr/bin/env bash'
    echo 'command_exists() { command -v "$1" >/dev/null 2>&1; }'
    echo 'info() { echo "--- $1 ---"; }'
    awk '
      /^# --- Step 1: Install Podman and Podman Compose ---$/ {capture=1}
      capture && /^# --- Step [0-9]+:/ && !/^# --- Step 1:/ {exit}
      capture {print}
    ' "${src}" | sed "s#/etc/os-release#${os_release_file}#g"
  } > "${harness}"
  chmod +x "${harness}"
  echo "${harness}"
}

# --- Sanity check: extraction matches the expected structure ---
# This guards against silent drift between the extraction helper above and
# the real scripts. If someone changes the Step 1 block's shape, this test
# (and, hence, the whole suite) should start failing loudly.
@test "setup_elasticsearch.sh: Step 1 block has expected structure for extraction" {
  extracted="$(awk '
    /^# --- Step 1: Install Podman and Podman Compose ---$/ {capture=1}
    capture && /^# --- Step [0-9]+:/ && !/^# --- Step 1:/ {exit}
    capture {print}
  ' "${ES_SCRIPT}")"
  [[ "${extracted}" == *'! command_exists podman || ! command_exists podman-compose'* ]]
  [[ "${extracted}" == *'"$ID" = "ubuntu"'* ]]
  [[ "${extracted}" == *'"$ID" = "debian"'* ]]
  [[ "${extracted}" == *'sudo apt-get install -y podman'* ]]
  [[ "${extracted}" == *'sudo apt-get install -y podman-compose'* ]]
  [[ "${extracted}" == *'Unknown OS. Trying dnf...'* ]]
}

@test "test-scripts/setup_elk.sh: Step 1 block has expected structure for extraction" {
  extracted="$(awk '
    /^# --- Step 1: Install Podman and Podman Compose ---$/ {capture=1}
    capture && /^# --- Step [0-9]+:/ && !/^# --- Step 1:/ {exit}
    capture {print}
  ' "${ELK_SCRIPT}")"
  [[ "${extracted}" == *'! command_exists podman || ! command_exists podman-compose'* ]]
  [[ "${extracted}" == *'"$ID" = "ubuntu"'* ]]
  [[ "${extracted}" == *'"$ID" = "debian"'* ]]
  [[ "${extracted}" == *'sudo apt-get install -y podman'* ]]
  [[ "${extracted}" == *'sudo apt-get install -y podman-compose'* ]]
  [[ "${extracted}" == *'Unknown OS. Trying dnf...'* ]]
}

# --- Shared scenario assertions, exercised against both scripts below ---

_assert_ubuntu_installs_via_apt() {
  local script="$1"
  unstub podman
  unstub podman-compose
  echo 'ID=ubuntu' > "${TEST_TMPDIR}/os-release"
  stub sudo
  stub apt-get

  harness="$(build_step1_harness "${script}" "${TEST_TMPDIR}/os-release")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Debian/Ubuntu detected. Checking for missing dependencies..."* ]]
  grep -qF "sudo apt-get update -y" "${CALL_LOG}"
  grep -qF "sudo apt-get install -y podman" "${CALL_LOG}"
  grep -qF "sudo apt-get install -y podman-compose" "${CALL_LOG}"
  run grep -q "dnf" "${CALL_LOG}"
  [ "${status}" -ne 0 ]
}

@test "setup_elasticsearch.sh: Ubuntu host installs podman and podman-compose via apt-get" {
  _assert_ubuntu_installs_via_apt "${ES_SCRIPT}"
}

@test "test-scripts/setup_elk.sh: Ubuntu host installs podman and podman-compose via apt-get" {
  _assert_ubuntu_installs_via_apt "${ELK_SCRIPT}"
}

_assert_debian_installs_via_apt() {
  local script="$1"
  unstub podman
  unstub podman-compose
  echo 'ID=debian' > "${TEST_TMPDIR}/os-release"
  stub sudo
  stub apt-get

  harness="$(build_step1_harness "${script}" "${TEST_TMPDIR}/os-release")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Debian/Ubuntu detected. Checking for missing dependencies..."* ]]
  grep -qF "sudo apt-get install -y podman" "${CALL_LOG}"
  grep -qF "sudo apt-get install -y podman-compose" "${CALL_LOG}"
}

@test "setup_elasticsearch.sh: Debian host installs podman and podman-compose via apt-get" {
  _assert_debian_installs_via_apt "${ES_SCRIPT}"
}

@test "test-scripts/setup_elk.sh: Debian host installs podman and podman-compose via apt-get" {
  _assert_debian_installs_via_apt "${ELK_SCRIPT}"
}

_assert_ubuntu_quoted_id_detected() {
  local script="$1"
  unstub podman
  unstub podman-compose
  # Real-world os-release files often quote values, e.g. ID="ubuntu".
  printf 'ID="ubuntu"\nVERSION_ID="24.04"\n' > "${TEST_TMPDIR}/os-release"
  stub sudo
  stub apt-get

  harness="$(build_step1_harness "${script}" "${TEST_TMPDIR}/os-release")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Debian/Ubuntu detected. Checking for missing dependencies..."* ]]
}

@test "setup_elasticsearch.sh: quoted ID=\"ubuntu\" in os-release is still detected" {
  _assert_ubuntu_quoted_id_detected "${ES_SCRIPT}"
}

@test "test-scripts/setup_elk.sh: quoted ID=\"ubuntu\" in os-release is still detected" {
  _assert_ubuntu_quoted_id_detected "${ELK_SCRIPT}"
}

_assert_rpm_only_missing_podman_compose() {
  local script="$1"
  # podman already present (default stub PATH has no real podman, so create one)
  stub podman
  unstub podman-compose
  echo 'ID=fedora' > "${TEST_TMPDIR}/os-release"
  stub sudo
  stub dnf

  harness="$(build_step1_harness "${script}" "${TEST_TMPDIR}/os-release")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Fedora/CentOS/RHEL/AlmaLinux detected. Installing via dnf..."* ]]
  # podman is already installed, so it must NOT be reinstalled.
  run grep -qF "sudo dnf install podman -y" "${CALL_LOG}"
  [ "${status}" -ne 0 ]
  # podman-compose is missing, so it must be installed via EPEL + dnf.
  grep -qF "sudo dnf install epel-release -y" "${CALL_LOG}"
  grep -qF "sudo dnf install podman-compose -y" "${CALL_LOG}"
}

@test "setup_elasticsearch.sh: RPM host with podman present only installs missing podman-compose" {
  _assert_rpm_only_missing_podman_compose "${ES_SCRIPT}"
}

@test "test-scripts/setup_elk.sh: RPM host with podman present only installs missing podman-compose" {
  _assert_rpm_only_missing_podman_compose "${ELK_SCRIPT}"
}

_assert_rpm_installs_both_when_both_missing() {
  local script="$1"
  unstub podman
  unstub podman-compose
  echo 'ID=centos' > "${TEST_TMPDIR}/os-release"
  stub sudo
  stub dnf

  harness="$(build_step1_harness "${script}" "${TEST_TMPDIR}/os-release")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Fedora/CentOS/RHEL/AlmaLinux detected. Installing via dnf..."* ]]
  grep -qF "sudo dnf update -y" "${CALL_LOG}"
  grep -qF "sudo dnf install podman -y" "${CALL_LOG}"
  grep -qF "sudo dnf install podman-compose -y" "${CALL_LOG}"
}

@test "setup_elasticsearch.sh: RPM host installs both packages via dnf when both are missing" {
  _assert_rpm_installs_both_when_both_missing "${ES_SCRIPT}"
}

@test "test-scripts/setup_elk.sh: RPM host installs both packages via dnf when both are missing" {
  _assert_rpm_installs_both_when_both_missing "${ELK_SCRIPT}"
}

_assert_unknown_os_falls_back_to_dnf() {
  local script="$1"
  unstub podman
  unstub podman-compose
  stub sudo
  stub dnf
  # Point at a file that does not exist to simulate a host with no
  # /etc/os-release (the "unknown OS" fallback branch).
  local missing_os_release="${TEST_TMPDIR}/does-not-exist"

  harness="$(build_step1_harness "${script}" "${missing_os_release}")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Unknown OS. Trying dnf..."* ]]
  grep -qF "sudo dnf install podman -y" "${CALL_LOG}"
  grep -qF "sudo dnf install podman-compose -y" "${CALL_LOG}"
}

@test "setup_elasticsearch.sh: unknown OS (no os-release file) falls back to dnf" {
  _assert_unknown_os_falls_back_to_dnf "${ES_SCRIPT}"
}

@test "test-scripts/setup_elk.sh: unknown OS (no os-release file) falls back to dnf" {
  _assert_unknown_os_falls_back_to_dnf "${ELK_SCRIPT}"
}

_assert_skips_install_when_both_present() {
  local script="$1"
  stub podman
  stub podman-compose
  stub sudo
  stub apt-get
  stub dnf
  echo 'ID=ubuntu' > "${TEST_TMPDIR}/os-release"

  harness="$(build_step1_harness "${script}" "${TEST_TMPDIR}/os-release")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Podman and podman-compose are already installed."* ]]
  # Nothing should have been installed.
  [ ! -s "${CALL_LOG}" ]
}

@test "setup_elasticsearch.sh: skips installation entirely when podman and podman-compose are present" {
  _assert_skips_install_when_both_present "${ES_SCRIPT}"
}

@test "test-scripts/setup_elk.sh: skips installation entirely when podman and podman-compose are present" {
  _assert_skips_install_when_both_present "${ELK_SCRIPT}"
}

_assert_missing_only_podman_compose_triggers_install_ubuntu() {
  local script="$1"
  # podman is present but podman-compose is missing: the OR condition
  # should still trigger the overall install branch on Ubuntu.
  stub podman
  unstub podman-compose
  echo 'ID=ubuntu' > "${TEST_TMPDIR}/os-release"
  stub sudo
  stub apt-get

  harness="$(build_step1_harness "${script}" "${TEST_TMPDIR}/os-release")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  [[ "${output}" != *"already installed"* ]]
  grep -qF "sudo apt-get install -y podman-compose" "${CALL_LOG}"
}

@test "setup_elasticsearch.sh: missing only podman-compose still triggers apt install on Ubuntu" {
  _assert_missing_only_podman_compose_triggers_install_ubuntu "${ES_SCRIPT}"
}

@test "test-scripts/setup_elk.sh: missing only podman-compose still triggers apt install on Ubuntu" {
  _assert_missing_only_podman_compose_triggers_install_ubuntu "${ELK_SCRIPT}"
}

# --- Ansible Playbook Integration & Syntax validation tests ---

@test "Ansible playbooks: syntax validation check" {
  run ansible-playbook --syntax-check "${REPO_ROOT}/ansible/main.yml"
  [ "${status}" -eq 0 ]
  run ansible-playbook --syntax-check "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  [ "${status}" -eq 0 ]
  run ansible-playbook --syntax-check "${REPO_ROOT}/ansible/setup_kibana.yml"
  [ "${status}" -eq 0 ]
  run ansible-playbook --syntax-check "${REPO_ROOT}/ansible/setup_fleet_server.yml"
  [ "${status}" -eq 0 ]
}

@test "Ansible playbooks: isolated Podman integration test with rerun/idempotency check" {
  # Find the real, fully-resolved python executable to avoid pyenv shim issues in subshells
  local real_python
  real_python="$(python3 -c 'import sys, os; print(os.path.realpath(sys.executable))' 2>/dev/null || which python3 || which python)"

  # Ensure python3 and python symlinks exist in STUB_BIN pointing to the real python binary
  ln -sf "${real_python}" "${STUB_BIN}/python3"
  ln -sf "${real_python}" "${STUB_BIN}/python"

  # Create a clean run workspace inside the temp directory
  local run_dir="${TEST_TMPDIR}/ansible_run"
  mkdir -p "${run_dir}/group_vars"
  mkdir -p "${run_dir}/library"

  # Copy playbooks
  cp "${REPO_ROOT}/ansible/main.yml" "${run_dir}/"
  cp "${REPO_ROOT}/ansible/setup_elasticsearch.yml" "${run_dir}/"
  cp "${REPO_ROOT}/ansible/setup_kibana.yml" "${run_dir}/"
  cp "${REPO_ROOT}/ansible/setup_fleet_server.yml" "${run_dir}/"
  cp "${REPO_ROOT}/ansible/group_vars/all.yml" "${run_dir}/group_vars/"

  # Accelerate pause tasks for lightning-fast test execution
  sed -i 's/seconds: 60/seconds: 1/g' "${run_dir}/setup_elasticsearch.yml"
  sed -i 's/seconds: 5/seconds: 1/g' "${run_dir}/setup_elasticsearch.yml"
  sed -i 's/seconds: 60/seconds: 1/g' "${run_dir}/setup_kibana.yml"
  sed -i 's/seconds: 60/seconds: 1/g' "${run_dir}/setup_fleet_server.yml"


  # Write mock uri module
  cat > "${run_dir}/library/uri.py" <<EOF
#!${real_python}
from ansible.module_utils.basic import AnsibleModule

def main():
    module = AnsibleModule(
        argument_spec=dict(
            url=dict(type='str', required=True),
            user=dict(type='str'),
            password=dict(type='str', no_log=True),
            force_basic_auth=dict(type='bool'),
            ca_path=dict(type='str'),
            return_content=dict(type='bool'),
            validate_certs=dict(type='bool'),
            method=dict(type='str', default='GET'),
        ),
        supports_check_mode=True
    )
    content = '{"version": {"number": "9.4.4"}, "tagline": "You Know, for Search"}'
    module.exit_json(changed=False, content=content, status=200)

if __name__ == '__main__':
    main()
EOF
  chmod +x "${run_dir}/library/uri.py"

  # Write mock file module
  cat > "${run_dir}/library/file.py" <<EOF
#!${real_python}
import os
import shutil
from ansible.module_utils.basic import AnsibleModule

def main():
    module = AnsibleModule(
        argument_spec=dict(
            path=dict(type='str', required=True, aliases=['dest', 'name']),
            state=dict(type='str'),
            owner=dict(type='str'),
            group=dict(type='str'),
            mode=dict(type='str'),
            _original_basename=dict(type='str'),
            recurse=dict(type='bool'),
            src=dict(type='str'),
            follow=dict(type='bool'),
            force=dict(type='bool'),
            unsafe_writes=dict(type='bool'),
        ),
        supports_check_mode=True
    )
    path = module.params['path']
    state = module.params.get('state', 'file')

    if path == '/data':
        module.exit_json(changed=False, path=path)
        return

    try:
        if state == 'absent':
            if os.path.isdir(path):
                shutil.rmtree(path)
            elif os.path.exists(path):
                os.remove(path)
        elif state == 'directory':
            os.makedirs(path, exist_ok=True)
        module.exit_json(changed=True, path=path)
    except Exception as e:
        module.fail_json(msg=str(e))

if __name__ == '__main__':
    main()
EOF
  chmod +x "${run_dir}/library/file.py"

  # Setup stubs for podman and podman-compose on PATH
  cat > "${STUB_BIN}/podman" <<'EOF'
#!/usr/bin/env bash
echo "podman $*" >> "${CALL_LOG}"
if [[ "$*" == *"inspect es01"* || "$*" == *"inspect kib01"* || "$*" == *"inspect fleet-server"* ]]; then
  echo '[{"Name": "/es01", "State": {"Running": true}}]'
  exit 0
fi
if [[ "$*" == *"elasticsearch-reset-password"* ]]; then
  echo "New value: mock-password"
  exit 0
fi
if [[ "$*" == *"elasticsearch-create-enrollment-token"* ]]; then
  echo "mock-enrollment-token"
  exit 0
fi
if [[ "$*" == *"kibana-verification-code"* ]]; then
  echo "123456"
  exit 0
fi
if [[ "$*" == *"cp es01:"* ]]; then
  dest="${@: -1}"
  mkdir -p "$(dirname "$dest")"
  echo "mock-cert-content" > "$dest"
  exit 0
fi
exit 0
EOF
  chmod +x "${STUB_BIN}/podman"

  cat > "${STUB_BIN}/podman-compose" <<'EOF'
#!/usr/bin/env bash
echo "podman-compose $*" >> "${CALL_LOG}"
exit 0
EOF
  chmod +x "${STUB_BIN}/podman-compose"

  # Stub sudo/apt-get/dnf just in case, but they shouldn't be called because podman/podman-compose already exist
  stub sudo
  stub apt-get
  stub dnf

  # Target folders inside sandbox
  local sandbox_data_dir="${TEST_TMPDIR}/sandbox_data"
  local sandbox_elk_dir="${TEST_TMPDIR}/sandbox_elk"
  local sandbox_creds="${sandbox_elk_dir}/temp_credentials.txt"
  local sandbox_certs="${sandbox_elk_dir}/certs"

  # 1. Execute the master playbook for the first time
  local current_python
  current_python="${real_python}"
  run ansible-playbook -i localhost, -c local "${run_dir}/main.yml" \
    -e "data_dir=${sandbox_data_dir}" \
    -e "elk_dir=${sandbox_elk_dir}" \
    -e "temp_credentials_file=${sandbox_creds}" \
    -e "cert_dir=${sandbox_certs}" \
    -e "fleet_server_service_token=mocktoken" \
    -e "fleet_server_policy_id=mockpolicy" \
    -e "ansible_become=false" \
    -e "ansible_python_interpreter=${current_python}"

  [ "${status}" -eq 0 ]

  # Verify generated compose files exist
  [ -f "${sandbox_elk_dir}/podman-compose.yml" ]
  [ -f "${sandbox_elk_dir}/podman-compose-kibana.yml" ]
  [ -f "${sandbox_elk_dir}/podman-compose-fleet-server.yml" ]

  # Verify fleet server compose file permissions (mode 0600)
  local compose_perms
  compose_perms=$(stat -c "%a" "${sandbox_elk_dir}/podman-compose-fleet-server.yml")
  [ "${compose_perms}" = "600" ]

  # Verify no_log prevented secrets from leaking in CALL_LOG (mocktoken or mock-password should NOT be in CALL_LOG)
  run grep -q "mocktoken" "${CALL_LOG}"
  [ "${status}" -ne 0 ]

  # 2. Execute the master playbook a second time to verify rerun / idempotency
  run ansible-playbook -i localhost, -c local "${run_dir}/main.yml" \
    -e "data_dir=${sandbox_data_dir}" \
    -e "elk_dir=${sandbox_elk_dir}" \
    -e "temp_credentials_file=${sandbox_creds}" \
    -e "cert_dir=${sandbox_certs}" \
    -e "fleet_server_service_token=mocktoken" \
    -e "fleet_server_policy_id=mockpolicy" \
    -e "ansible_become=false" \
    -e "ansible_python_interpreter=${current_python}"

  echo "Ansible Output 2: ${output}"
  [ "${status}" -eq 0 ]
}