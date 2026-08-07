#!/usr/bin/env bats
#
# Tests for run_playbooks.sh, the master bash entry point that invokes the
# Ansible playbooks under ansible/ (see ansible/main.yml and PLAYBOOKS.md).
#
# ansible-playbook is stubbed out with a fake executable on PATH that simply
# records its invocation, so these tests exercise run_playbooks.sh's own
# logic (dependency check, banner message, argument construction and
# forwarding, exit code propagation) without requiring a real Ansible
# installation or performing any podman/network operations.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="${REPO_ROOT}/run_playbooks.sh"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  STUB_BIN="${TEST_TMPDIR}/bin"
  mkdir -p "${STUB_BIN}"
  CALL_LOG="${TEST_TMPDIR}/calls.log"
  : > "${CALL_LOG}"
  export CALL_LOG
  # Prepend the stub bin dir so our fake ansible-playbook takes priority.
  export PATH="${STUB_BIN}:${PATH}"

  # run_playbooks.sh resolves its own directory via
  # `dirname "$(realpath "$0")"`. All invocations below pass an
  # already-absolute path as $0, so a plain pass-through stub is a faithful,
  # self-contained stand-in for environments that lack GNU coreutils'
  # realpath, without depending on host tooling.
  cat > "${STUB_BIN}/realpath" <<'EOF'
#!/usr/bin/env bash
echo "$1"
EOF
  chmod +x "${STUB_BIN}/realpath"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

# Create a stub executable on PATH that logs its name and arguments and
# exits with the given code (0 by default).
stub() {
  local name="$1"
  local exit_code="${2:-0}"
  cat > "${STUB_BIN}/${name}" <<EOF
#!/usr/bin/env bash
echo "${name} \$*" >> "${CALL_LOG}"
exit ${exit_code}
EOF
  chmod +x "${STUB_BIN}/${name}"
}

@test "run_playbooks.sh is executable" {
  [ -x "${SCRIPT}" ]
}

@test "run_playbooks.sh exits with status 1 and a clear error when ansible-playbook is not installed" {
  run bash "${SCRIPT}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Error: ansible-playbook is not installed."* ]]
  [[ "${output}" == *"Please install Ansible before running this script."* ]]
  # Nothing should have been invoked since the dependency check failed first.
  [ ! -s "${CALL_LOG}" ]
}

@test "run_playbooks.sh prints the running banner and invokes ansible-playbook with the correct inventory and playbook path" {
  stub ansible-playbook

  run bash "${SCRIPT}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"--- Running Elastic Stack 9.4.4 setup using Ansible ---"* ]]
  grep -qF "ansible-playbook -i localhost, -c local ${REPO_ROOT}/ansible/main.yml" "${CALL_LOG}"
}

@test "run_playbooks.sh forwards additional command-line arguments to ansible-playbook" {
  stub ansible-playbook

  run bash "${SCRIPT}" -e "fleet_server_service_token=abc123" -e "fleet_server_policy_id=policy-1"

  [ "${status}" -eq 0 ]
  grep -qF -- "ansible-playbook -i localhost, -c local ${REPO_ROOT}/ansible/main.yml -e fleet_server_service_token=abc123 -e fleet_server_policy_id=policy-1" "${CALL_LOG}"
}

@test "run_playbooks.sh propagates ansible-playbook's exit code on failure" {
  stub ansible-playbook 3

  run bash "${SCRIPT}"

  [ "${status}" -eq 3 ]
  [ -s "${CALL_LOG}" ]
}

@test "run_playbooks.sh resolves the ansible directory relative to its own location regardless of the caller's working directory" {
  stub ansible-playbook

  run bash -c "cd '${TEST_TMPDIR}' && bash '${SCRIPT}'"

  [ "${status}" -eq 0 ]
  grep -qF "ansible-playbook -i localhost, -c local ${REPO_ROOT}/ansible/main.yml" "${CALL_LOG}"
}

@test "run_playbooks.sh does not call ansible-playbook when the dependency check fails, even with extra arguments" {
  run bash "${SCRIPT}" -e "foo=bar"

  [ "${status}" -eq 1 ]
  [ ! -s "${CALL_LOG}" ]
}