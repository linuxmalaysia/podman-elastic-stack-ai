#!/usr/bin/env bats
#
# Tests for the "Source common utilities" block added to
# setup_elasticsearch.sh, setup_fleet_server.sh, setup_kibana.sh, and
# test-scripts/setup_elk.sh. Each of these scripts previously defined its
# own copy of command_exists() inline; they now source the shared
# scripts/utils.sh, looking first at "${SCRIPT_DIR}/scripts/utils.sh" and
# falling back to "${SCRIPT_DIR}/../scripts/utils.sh", and exiting with an
# error if neither is found.
#
# The sourcing block is extracted verbatim from each real script (via awk,
# using the "# Source common utilities" / trailing "fi" markers already
# present in the source) so each scenario (primary path, fallback path,
# neither path, precedence) can be exercised in isolation without actually
# running the rest of the (side-effecting) setup scripts.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

ES_SCRIPT="${REPO_ROOT}/setup_elasticsearch.sh"
FLEET_SCRIPT="${REPO_ROOT}/setup_fleet_server.sh"
KIBANA_SCRIPT="${REPO_ROOT}/setup_kibana.sh"
ELK_SCRIPT="${REPO_ROOT}/test-scripts/setup_elk.sh"

ALL_SCRIPTS=("${ES_SCRIPT}" "${FLEET_SCRIPT}" "${KIBANA_SCRIPT}" "${ELK_SCRIPT}")

setup() {
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

# Extracts the "# Source common utilities" block (the if/elif/else/fi that
# sources scripts/utils.sh) from the given script, verbatim.
extract_source_utils_block() {
  local src="$1"
  awk '
    /^# Source common utilities$/ {capture=1; print; next}
    capture {print}
    capture && /^fi$/ {exit}
  ' "${src}"
}

# Builds a standalone executable harness that: sets SCRIPT_DIR to the given
# value, embeds the extracted sourcing block from $src, and then reports
# whether command_exists ended up defined (and, if so, how it behaves).
build_harness() {
  local src="$1"
  local script_dir_value="$2"
  local harness="${TEST_TMPDIR}/harness_$$_${RANDOM}.sh"

  {
    echo '#!/usr/bin/env bash'
    echo "SCRIPT_DIR=\"${script_dir_value}\""
    extract_source_utils_block "${src}"
    echo 'if declare -f command_exists >/dev/null 2>&1; then'
    echo '  echo "COMMAND_EXISTS_DEFINED=true"'
    echo '  command_exists bash && echo "BASH_FOUND=true" || echo "BASH_FOUND=false"'
    echo '  command_exists this_command_definitely_does_not_exist_xyz123 && echo "FAKE_FOUND=true" || echo "FAKE_FOUND=false"'
    echo 'else'
    echo '  echo "COMMAND_EXISTS_DEFINED=false"'
    echo 'fi'
  } > "${harness}"
  chmod +x "${harness}"
  echo "${harness}"
}

# --- Sanity check: extraction matches the expected structure ---
# Guards against silent drift between the extraction helper above and the
# real scripts. If someone changes the shape of the sourcing block, this
# test (and hence the whole suite) should fail loudly.
_assert_extraction_has_expected_shape() {
  local script="$1"
  local extracted
  extracted="$(extract_source_utils_block "${script}")"
  [[ "${extracted}" == *'if [ -f "${SCRIPT_DIR}/scripts/utils.sh" ]; then'* ]]
  [[ "${extracted}" == *'source "${SCRIPT_DIR}/scripts/utils.sh"'* ]]
  [[ "${extracted}" == *'elif [ -f "${SCRIPT_DIR}/../scripts/utils.sh" ]; then'* ]]
  [[ "${extracted}" == *'source "${SCRIPT_DIR}/../scripts/utils.sh"'* ]]
  [[ "${extracted}" == *'echo "Error: utils.sh not found."'* ]]
  [[ "${extracted}" == *'exit 1'* ]]
}

@test "setup_elasticsearch.sh: sourcing block has expected structure for extraction" {
  _assert_extraction_has_expected_shape "${ES_SCRIPT}"
}

@test "setup_fleet_server.sh: sourcing block has expected structure for extraction" {
  _assert_extraction_has_expected_shape "${FLEET_SCRIPT}"
}

@test "setup_kibana.sh: sourcing block has expected structure for extraction" {
  _assert_extraction_has_expected_shape "${KIBANA_SCRIPT}"
}

@test "test-scripts/setup_elk.sh: sourcing block has expected structure for extraction" {
  _assert_extraction_has_expected_shape "${ELK_SCRIPT}"
}

# --- All four scripts no longer define their own inline command_exists ---

@test "setup_elasticsearch.sh no longer declares an inline command_exists function" {
  run grep -qE '^command_exists\s*\(\)\s*\{' "${ES_SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "setup_fleet_server.sh no longer declares an inline command_exists function" {
  run grep -qE '^command_exists\s*\(\)\s*\{' "${FLEET_SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "setup_kibana.sh no longer declares an inline command_exists function" {
  run grep -qE '^command_exists\s*\(\)\s*\{' "${KIBANA_SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "test-scripts/setup_elk.sh no longer declares an inline command_exists function" {
  run grep -qE '^command_exists\s*\(\)\s*\{' "${ELK_SCRIPT}"
  [ "${status}" -ne 0 ]
}

# --- All four scripts still have valid bash syntax after the refactor ---

@test "setup_elasticsearch.sh has valid bash syntax" {
  run bash -n "${ES_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "setup_fleet_server.sh has valid bash syntax" {
  run bash -n "${FLEET_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "setup_kibana.sh has valid bash syntax" {
  run bash -n "${KIBANA_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "test-scripts/setup_elk.sh has valid bash syntax" {
  run bash -n "${ELK_SCRIPT}"
  [ "${status}" -eq 0 ]
}

# --- Scenario: primary path (${SCRIPT_DIR}/scripts/utils.sh) exists ---

_assert_sources_via_primary_path() {
  local script="$1"
  local script_dir="${TEST_TMPDIR}/primary_script_dir"
  mkdir -p "${script_dir}/scripts"
  cp "${REPO_ROOT}/scripts/utils.sh" "${script_dir}/scripts/utils.sh"

  local harness
  harness="$(build_harness "${script}" "${script_dir}")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"COMMAND_EXISTS_DEFINED=true"* ]]
  [[ "${output}" == *"BASH_FOUND=true"* ]]
  [[ "${output}" == *"FAKE_FOUND=false"* ]]
}

@test "setup_elasticsearch.sh: sources utils.sh via primary path (SCRIPT_DIR/scripts/utils.sh)" {
  _assert_sources_via_primary_path "${ES_SCRIPT}"
}

@test "setup_fleet_server.sh: sources utils.sh via primary path (SCRIPT_DIR/scripts/utils.sh)" {
  _assert_sources_via_primary_path "${FLEET_SCRIPT}"
}

@test "setup_kibana.sh: sources utils.sh via primary path (SCRIPT_DIR/scripts/utils.sh)" {
  _assert_sources_via_primary_path "${KIBANA_SCRIPT}"
}

@test "test-scripts/setup_elk.sh: sources utils.sh via primary path (SCRIPT_DIR/scripts/utils.sh)" {
  _assert_sources_via_primary_path "${ELK_SCRIPT}"
}

# --- Scenario: primary path missing, fallback (${SCRIPT_DIR}/../scripts/utils.sh) exists ---
# This mirrors the real-world layout of test-scripts/setup_elk.sh, whose
# SCRIPT_DIR is the test-scripts/ directory itself (no scripts/ subdirectory
# beneath it), while scripts/utils.sh lives one level up, at the repo root.

_assert_sources_via_fallback_path() {
  local script="$1"
  local base_dir="${TEST_TMPDIR}/fallback_base"
  local script_dir="${base_dir}/subdir"
  mkdir -p "${script_dir}"
  mkdir -p "${base_dir}/scripts"
  cp "${REPO_ROOT}/scripts/utils.sh" "${base_dir}/scripts/utils.sh"
  # Deliberately do NOT create "${script_dir}/scripts/utils.sh" so the
  # primary branch's [ -f ... ] check fails and the elif fallback is taken.

  local harness
  harness="$(build_harness "${script}" "${script_dir}")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"COMMAND_EXISTS_DEFINED=true"* ]]
  [[ "${output}" == *"BASH_FOUND=true"* ]]
  [[ "${output}" == *"FAKE_FOUND=false"* ]]
}

@test "setup_elasticsearch.sh: falls back to SCRIPT_DIR/../scripts/utils.sh when primary path is missing" {
  _assert_sources_via_fallback_path "${ES_SCRIPT}"
}

@test "setup_fleet_server.sh: falls back to SCRIPT_DIR/../scripts/utils.sh when primary path is missing" {
  _assert_sources_via_fallback_path "${FLEET_SCRIPT}"
}

@test "setup_kibana.sh: falls back to SCRIPT_DIR/../scripts/utils.sh when primary path is missing" {
  _assert_sources_via_fallback_path "${KIBANA_SCRIPT}"
}

@test "test-scripts/setup_elk.sh: falls back to SCRIPT_DIR/../scripts/utils.sh when primary path is missing" {
  _assert_sources_via_fallback_path "${ELK_SCRIPT}"
}

# --- Scenario: neither path exists -> script errors out and exits 1 ---

_assert_errors_when_utils_not_found() {
  local script="$1"
  local script_dir="${TEST_TMPDIR}/empty_script_dir"
  mkdir -p "${script_dir}"
  # No "scripts/" directory here, and none in its (nonexistent) parent
  # either, since TEST_TMPDIR has no scripts/utils.sh at any level.

  local harness
  harness="$(build_harness "${script}" "${script_dir}")"
  run bash "${harness}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Error: utils.sh not found."* ]]
  [[ "${output}" != *"COMMAND_EXISTS_DEFINED"* ]]
}

@test "setup_elasticsearch.sh: exits with an error when utils.sh cannot be found at either path" {
  _assert_errors_when_utils_not_found "${ES_SCRIPT}"
}

@test "setup_fleet_server.sh: exits with an error when utils.sh cannot be found at either path" {
  _assert_errors_when_utils_not_found "${FLEET_SCRIPT}"
}

@test "setup_kibana.sh: exits with an error when utils.sh cannot be found at either path" {
  _assert_errors_when_utils_not_found "${KIBANA_SCRIPT}"
}

@test "test-scripts/setup_elk.sh: exits with an error when utils.sh cannot be found at either path" {
  _assert_errors_when_utils_not_found "${ELK_SCRIPT}"
}

# --- Scenario: both paths exist -> the primary path takes precedence ---
# Each candidate utils.sh defines command_exists differently (via a sentinel
# variable) so we can prove which file actually got sourced.

_assert_primary_path_takes_precedence_over_fallback() {
  local script="$1"
  local base_dir="${TEST_TMPDIR}/precedence_base"
  local script_dir="${base_dir}/subdir"
  mkdir -p "${script_dir}/scripts"
  mkdir -p "${base_dir}/scripts"

  cat > "${script_dir}/scripts/utils.sh" <<'EOF'
#!/bin/bash
command_exists() {
  command -v "$1" >/dev/null 2>&1
}
SOURCED_FROM="primary"
EOF

  cat > "${base_dir}/scripts/utils.sh" <<'EOF'
#!/bin/bash
command_exists() {
  command -v "$1" >/dev/null 2>&1
}
SOURCED_FROM="fallback"
EOF

  local harness="${TEST_TMPDIR}/precedence_harness.sh"
  {
    echo '#!/usr/bin/env bash'
    echo "SCRIPT_DIR=\"${script_dir}\""
    extract_source_utils_block "${script}"
    echo 'echo "SOURCED_FROM=${SOURCED_FROM}"'
  } > "${harness}"
  chmod +x "${harness}"

  run bash "${harness}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"SOURCED_FROM=primary"* ]]
}

@test "setup_elasticsearch.sh: primary path takes precedence when both primary and fallback utils.sh exist" {
  _assert_primary_path_takes_precedence_over_fallback "${ES_SCRIPT}"
}

@test "setup_fleet_server.sh: primary path takes precedence when both primary and fallback utils.sh exist" {
  _assert_primary_path_takes_precedence_over_fallback "${FLEET_SCRIPT}"
}

@test "setup_kibana.sh: primary path takes precedence when both primary and fallback utils.sh exist" {
  _assert_primary_path_takes_precedence_over_fallback "${KIBANA_SCRIPT}"
}

@test "test-scripts/setup_elk.sh: primary path takes precedence when both primary and fallback utils.sh exist" {
  _assert_primary_path_takes_precedence_over_fallback "${ELK_SCRIPT}"
}

# --- Scenario: real repository layout resolves correctly for every script ---
# This exercises the sourcing block against the actual on-disk repo layout
# (no fixtures), verifying command_exists really is usable afterwards for
# the "Step 1: Check Prerequisites" / "Step 1: Install Podman..." blocks
# that immediately follow it in each script.

@test "setup_elasticsearch.sh: resolves utils.sh correctly against the real repo layout (SCRIPT_DIR=repo root)" {
  harness="$(build_harness "${ES_SCRIPT}" "${REPO_ROOT}")"
  run bash "${harness}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"COMMAND_EXISTS_DEFINED=true"* ]]
  [[ "${output}" == *"BASH_FOUND=true"* ]]
}

@test "setup_fleet_server.sh: resolves utils.sh correctly against the real repo layout (SCRIPT_DIR=repo root)" {
  harness="$(build_harness "${FLEET_SCRIPT}" "${REPO_ROOT}")"
  run bash "${harness}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"COMMAND_EXISTS_DEFINED=true"* ]]
  [[ "${output}" == *"BASH_FOUND=true"* ]]
}

@test "setup_kibana.sh: resolves utils.sh correctly against the real repo layout (SCRIPT_DIR=repo root)" {
  harness="$(build_harness "${KIBANA_SCRIPT}" "${REPO_ROOT}")"
  run bash "${harness}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"COMMAND_EXISTS_DEFINED=true"* ]]
  [[ "${output}" == *"BASH_FOUND=true"* ]]
}

@test "test-scripts/setup_elk.sh: resolves utils.sh correctly against the real repo layout (SCRIPT_DIR=test-scripts dir)" {
  # test-scripts/setup_elk.sh's SCRIPT_DIR is test-scripts/ itself, which has
  # no scripts/ subdirectory, so this exercises the real fallback branch
  # (SCRIPT_DIR/../scripts/utils.sh -> repo_root/scripts/utils.sh).
  harness="$(build_harness "${ELK_SCRIPT}" "${REPO_ROOT}/test-scripts")"
  run bash "${harness}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"COMMAND_EXISTS_DEFINED=true"* ]]
  [[ "${output}" == *"BASH_FOUND=true"* ]]
}