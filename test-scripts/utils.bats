#!/usr/bin/env bats
#
# Tests for scripts/utils.sh, the shared utility library introduced to
# de-duplicate the command_exists() helper that was previously copy-pasted
# into setup_elasticsearch.sh, setup_fleet_server.sh, setup_kibana.sh, and
# test-scripts/setup_elk.sh.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
UTILS_SCRIPT="${REPO_ROOT}/scripts/utils.sh"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "scripts/utils.sh exists and is readable" {
  [ -f "${UTILS_SCRIPT}" ]
  [ -r "${UTILS_SCRIPT}" ]
}

@test "scripts/utils.sh has valid bash syntax" {
  run bash -n "${UTILS_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "scripts/utils.sh declares a command_exists function" {
  run grep -qE '^command_exists\s*\(\)' "${UTILS_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "scripts/utils.sh can be sourced without error and defines command_exists" {
  run bash -c "source '${UTILS_SCRIPT}' && declare -f command_exists >/dev/null && echo DEFINED"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"DEFINED"* ]]
}

@test "sourcing scripts/utils.sh does not print anything to stdout or exit the shell" {
  run bash -c "source '${UTILS_SCRIPT}'; echo AFTER_SOURCE"
  [ "${status}" -eq 0 ]
  [ "${output}" = "AFTER_SOURCE" ]
}

@test "command_exists returns success (0) for a command that is on PATH" {
  run bash -c "source '${UTILS_SCRIPT}' && command_exists bash"
  [ "${status}" -eq 0 ]
}

@test "command_exists returns failure (1) for a command that does not exist" {
  run bash -c "source '${UTILS_SCRIPT}' && command_exists this_command_definitely_does_not_exist_xyz123"
  [ "${status}" -eq 1 ]
}

@test "command_exists produces no stdout/stderr output of its own" {
  # command_exists must be silent regardless of whether the command exists,
  # since callers rely on it purely for its exit status.
  run bash -c "source '${UTILS_SCRIPT}' && command_exists bash; echo \"exit=\$?\""
  [ "${status}" -eq 0 ]
  [ "${output}" = "exit=0" ]

  run bash -c "source '${UTILS_SCRIPT}' && command_exists this_command_definitely_does_not_exist_xyz123; echo \"exit=\$?\""
  [ "${status}" -eq 0 ]
  [ "${output}" = "exit=1" ]
}

@test "command_exists finds a custom executable added to PATH" {
  mkdir -p "${TEST_TMPDIR}/bin"
  cat > "${TEST_TMPDIR}/bin/my-custom-tool" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${TEST_TMPDIR}/bin/my-custom-tool"

  run bash -c "export PATH='${TEST_TMPDIR}/bin:${PATH}'; source '${UTILS_SCRIPT}' && command_exists my-custom-tool"
  [ "${status}" -eq 0 ]
}

@test "command_exists also recognizes shell builtins and functions (command -v semantics)" {
  # command -v (used internally by command_exists) resolves builtins and
  # functions too, not just executables on PATH. This documents/locks in
  # that behavior since callers may rely on it for things like "cd" or
  # other builtins.
  run bash -c "source '${UTILS_SCRIPT}' && command_exists cd"
  [ "${status}" -eq 0 ]
}

@test "command_exists called with an empty string argument fails cleanly (no crash)" {
  run bash -c "source '${UTILS_SCRIPT}' && command_exists ''"
  [ "${status}" -eq 1 ]
}

@test "command_exists called with no arguments fails cleanly (no crash)" {
  run bash -c "source '${UTILS_SCRIPT}' && command_exists"
  [ "${status}" -eq 1 ]
}