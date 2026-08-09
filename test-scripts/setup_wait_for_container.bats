#!/usr/bin/env bats
#
# Tests for the "wait for container to start" polling loops introduced in
# setup_elasticsearch.sh, setup_fleet_server.sh, setup_kibana.sh, and
# test-scripts/setup_elk.sh.
#
# Previously each loop simply slept for a fixed number of seconds while
# repeatedly printing "podman ps -a" (or "podman ps -a --filter ...") on
# every iteration, regardless of whether the container had actually
# started. The loops now poll `podman inspect -f '{{.State.Running}}'
# <container>` on every iteration and `break` out of the loop as soon as
# the container reports as running, only printing a single podman ps
# summary (filtered by container name) once, after the loop ends (for
# setup_elasticsearch.sh, setup_fleet_server.sh, and setup_kibana.sh).
#
# Each loop is extracted verbatim from the real script (via awk, using
# literal start/end markers already present in the source, matched with
# plain substring comparison rather than regex to avoid having to escape
# shell metacharacters like "${...}" that appear in the loop bodies) and
# wrapped in a standalone harness so it can be exercised in isolation,
# with `podman` and `sleep` replaced by stub executables on PATH.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

ES_SCRIPT="${REPO_ROOT}/setup_elasticsearch.sh"
FLEET_SCRIPT="${REPO_ROOT}/setup_fleet_server.sh"
KIBANA_SCRIPT="${REPO_ROOT}/setup_kibana.sh"
ELK_SCRIPT="${REPO_ROOT}/test-scripts/setup_elk.sh"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  STUB_BIN="${TEST_TMPDIR}/bin"
  mkdir -p "${STUB_BIN}"
  CALL_LOG="${TEST_TMPDIR}/calls.log"
  : > "${CALL_LOG}"
  export CALL_LOG
  export PATH="${STUB_BIN}:${PATH}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

# Create a stub executable on PATH that logs its invocation and exits 0.
stub() {
  local name="$1"
  cat > "${STUB_BIN}/${name}" <<EOF
#!/usr/bin/env bash
echo "${name} \$*" >> "${CALL_LOG}"
exit 0
EOF
  chmod +x "${STUB_BIN}/${name}"
}

# Creates a `podman` stub on PATH that:
#   - logs every invocation (including subcommand and args) to CALL_LOG
#   - for `podman inspect ...` calls, maintains a counter in
#     TEST_TMPDIR/inspect_count and prints "true" once the counter reaches
#     true_after, otherwise prints "false"
#   - for every other subcommand (e.g. `podman ps ...`), just logs and
#     exits 0
create_podman_stub() {
  local true_after="$1"
  cat > "${STUB_BIN}/podman" <<EOF
#!/usr/bin/env bash
echo "podman \$*" >> "${CALL_LOG}"
if [ "\$1" = "inspect" ]; then
  count_file="${TEST_TMPDIR}/inspect_count"
  count=0
  if [ -f "\${count_file}" ]; then
    count=\$(cat "\${count_file}")
  fi
  count=\$((count + 1))
  echo "\${count}" > "\${count_file}"
  if [ "\${count}" -ge ${true_after} ]; then
    echo "true"
  else
    echo "false"
  fi
  exit 0
fi
exit 0
EOF
  chmod +x "${STUB_BIN}/podman"
}

# Extracts the lines from (and including) the first line that starts with
# ${start} up to (but not including, unless include_end=1) the first
# subsequent line that starts with ${end}. Uses plain substring comparison
# (awk's index()) rather than regex matching, since the loop bodies contain
# "${VAR}" shell expansions that would otherwise need ERE escaping.
extract_block() {
  local file="$1" start="$2" end="$3" include_end="${4:-0}"
  awk -v start="${start}" -v end="${end}" -v include_end="${include_end}" '
    index($0, start) == 1 { capture = 1 }
    capture && index($0, end) == 1 {
      if (include_end == "1") { print }
      exit
    }
    capture { print }
  ' "${file}"
}

# Builds a standalone executable harness: defines info(), assigns any
# extra variables the extracted block depends on, then embeds the
# extracted block verbatim.
build_harness() {
  local extracted="$1" extra_vars="$2"
  local harness="${TEST_TMPDIR}/harness_$$_${RANDOM}.sh"
  {
    echo '#!/usr/bin/env bash'
    echo 'info() { echo "--- $1 ---"; }'
    echo "${extra_vars}"
    echo "${extracted}"
  } > "${harness}"
  chmod +x "${harness}"
  echo "${harness}"
}

# --- Sanity checks: extraction matches the expected structure ---
# Guards against silent drift between the markers used here and the real
# scripts. If someone changes the shape of the wait loop, these tests
# (and hence the rest of the suite) should fail loudly.

@test "setup_elasticsearch.sh: wait loop has expected structure for extraction" {
  extracted="$(extract_block "${ES_SCRIPT}" \
    "# --- Step 6: Retrieve and Store Elasticsearch Password ---" \
    "# Change to the base directory")"
  [[ "${extracted}" == *'for i in $(seq 60 -1 1); do'* ]]
  [[ "${extracted}" == *"podman inspect -f '{{.State.Running}}' \"\${CONTAINER_NAME}\" 2>/dev/null"* ]]
  [[ "${extracted}" == *'break'* ]]
  [[ "${extracted}" == *'sleep 1'* ]]
  [[ "${extracted}" == *'done'* ]]
  [[ "${extracted}" == *'Elasticsearch container is running.'* ]]
  [[ "${extracted}" == *'podman ps -a --filter name="${CONTAINER_NAME}"'* ]]
}

@test "setup_fleet_server.sh: wait loop has expected structure for extraction" {
  extracted="$(extract_block "${FLEET_SCRIPT}" \
    "# --- Step 9: Wait for Fleet Server to Start ---" \
    'info "Fleet Server setup complete')"
  [[ "${extracted}" == *'for i in $(seq "$MAX_WAIT_SECONDS" -1 1); do'* ]]
  [[ "${extracted}" == *"podman inspect -f '{{.State.Running}}' \"\${FLEET_SERVER_CONTAINER_NAME}\" 2>/dev/null"* ]]
  [[ "${extracted}" == *'break'* ]]
  [[ "${extracted}" == *'sleep 1'* ]]
  [[ "${extracted}" == *'done'* ]]
  [[ "${extracted}" == *'Fleet Server start process complete. You can check the status below:'* ]]
  [[ "${extracted}" == *'podman ps -a --filter name="${FLEET_SERVER_CONTAINER_NAME}"'* ]]
}

@test "setup_kibana.sh: wait loop has expected structure for extraction" {
  extracted="$(extract_block "${KIBANA_SCRIPT}" \
    "# --- Step 7: Wait for Kibana Container to be Running ---" \
    "# --- Step 8: Get Elasticsearch Container IP Address ---")"
  [[ "${extracted}" == *'for i in $(seq "$MAX_WAIT_SECONDS" -1 1); do'* ]]
  [[ "${extracted}" == *"podman inspect -f '{{.State.Running}}' \"\${KIBANA_CONTAINER_NAME}\" 2>/dev/null"* ]]
  [[ "${extracted}" == *'break'* ]]
  [[ "${extracted}" == *'sleep 1'* ]]
  [[ "${extracted}" == *'done'* ]]
  [[ "${extracted}" == *'Kibana start process waiting complete. You can check the status below:'* ]]
  [[ "${extracted}" == *'podman ps -a --filter name="${KIBANA_CONTAINER_NAME}"'* ]]
}

@test "test-scripts/setup_elk.sh: wait loop has expected structure for extraction" {
  extracted="$(extract_block "${ELK_SCRIPT}" \
    "# --- Step 6: Retrieve and Store Elasticsearch Password ---" \
    "# Change to the base directory")"
  [[ "${extracted}" == *'for i in $(seq 60 -1 1); do'* ]]
  [[ "${extracted}" == *"podman inspect -f '{{.State.Running}}' es01 2>/dev/null"* ]]
  [[ "${extracted}" == *'break'* ]]
  [[ "${extracted}" == *'sleep 1'* ]]
  [[ "${extracted}" == *'done'* ]]
}

# --- Scenario: container is already running on the very first check ---
# The loop must break immediately, before printing any "Waiting for..."
# message, and only the "waiting" preamble should have been sleep-free.

_assert_breaks_immediately_when_already_running() {
  local script="$1" start="$2" end="$3" include_end="$4" extra_vars="$5" \
        waiting_msg="$6" container_name="$7"

  create_podman_stub 1
  stub sleep

  local extracted
  extracted="$(extract_block "${script}" "${start}" "${end}" "${include_end}")"
  local harness
  harness="$(build_harness "${extracted}" "${extra_vars}")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  # No "Waiting for..." message should have been printed: the very first
  # inspect check already reports the container as running.
  run grep -c "${waiting_msg}.*seconds remaining..." <<< "${output}"
  [ "${output}" = "0" ]
  # Exactly one inspect call was made before breaking.
  [ "$(grep -c "podman inspect" "${CALL_LOG}")" -eq 1 ]
  [[ "$(cat "${CALL_LOG}")" == *"${container_name}"* ]]
  # sleep must never have been called, since we broke out before reaching it.
  run grep -q "^sleep" "${CALL_LOG}"
  [ "${status}" -ne 0 ]
}

@test "setup_elasticsearch.sh: breaks immediately without waiting when container is already running" {
  _assert_breaks_immediately_when_already_running "${ES_SCRIPT}" \
    "# --- Step 6: Retrieve and Store Elasticsearch Password ---" \
    "# Change to the base directory" 0 \
    'CONTAINER_NAME="es01"' \
    "Elasticsearch to start... " "es01"
}

@test "setup_fleet_server.sh: breaks immediately without waiting when container is already running" {
  _assert_breaks_immediately_when_already_running "${FLEET_SCRIPT}" \
    "# --- Step 9: Wait for Fleet Server to Start ---" \
    'info "Fleet Server setup complete' 0 \
    'FLEET_SERVER_CONTAINER_NAME="fleet-server"' \
    "Fleet Server to start... " "fleet-server"
}

@test "setup_kibana.sh: breaks immediately without waiting when container is already running" {
  _assert_breaks_immediately_when_already_running "${KIBANA_SCRIPT}" \
    "# --- Step 7: Wait for Kibana Container to be Running ---" \
    "# --- Step 8: Get Elasticsearch Container IP Address ---" 0 \
    'KIBANA_CONTAINER_NAME="kib01"' \
    "Kibana to start... " "kib01"
}

@test "test-scripts/setup_elk.sh: breaks immediately without waiting when container is already running" {
  _assert_breaks_immediately_when_already_running "${ELK_SCRIPT}" \
    "# --- Step 6: Retrieve and Store Elasticsearch Password ---" \
    "# Change to the base directory" 0 \
    "" \
    "Elasticsearch to start... " "es01"
}

# --- Scenario: container starts running partway through the loop ---
# Only (N-1) "Waiting for..." messages should print before the Nth check
# succeeds and the loop breaks, since the check happens before the echo
# on each iteration.

_assert_breaks_after_n_checks() {
  local script="$1" start="$2" end="$3" include_end="$4" extra_vars="$5" \
        waiting_msg="$6" n="$7"

  create_podman_stub "${n}"
  stub sleep

  local extracted
  extracted="$(extract_block "${script}" "${start}" "${end}" "${include_end}")"
  local harness
  harness="$(build_harness "${extracted}" "${extra_vars}")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  local waiting_count
  waiting_count="$(grep -c "${waiting_msg}.*seconds remaining..." <<< "${output}" || true)"
  [ "${waiting_count}" -eq "$((n - 1))" ]
  [ "$(grep -c "podman inspect" "${CALL_LOG}")" -eq "${n}" ]
  [ "$(grep -c "^sleep" "${CALL_LOG}")" -eq "$((n - 1))" ]
}

@test "setup_elasticsearch.sh: waits and prints (N-1) status messages before breaking on the Nth check" {
  _assert_breaks_after_n_checks "${ES_SCRIPT}" \
    "# --- Step 6: Retrieve and Store Elasticsearch Password ---" \
    "# Change to the base directory" 0 \
    'CONTAINER_NAME="es01"' \
    "Elasticsearch to start... " 5
}

@test "setup_fleet_server.sh: waits and prints (N-1) status messages before breaking on the Nth check" {
  _assert_breaks_after_n_checks "${FLEET_SCRIPT}" \
    "# --- Step 9: Wait for Fleet Server to Start ---" \
    'info "Fleet Server setup complete' 0 \
    'FLEET_SERVER_CONTAINER_NAME="fleet-server"' \
    "Fleet Server to start... " 5
}

@test "setup_kibana.sh: waits and prints (N-1) status messages before breaking on the Nth check" {
  _assert_breaks_after_n_checks "${KIBANA_SCRIPT}" \
    "# --- Step 7: Wait for Kibana Container to be Running ---" \
    "# --- Step 8: Get Elasticsearch Container IP Address ---" 0 \
    'KIBANA_CONTAINER_NAME="kib01"' \
    "Kibana to start... " 5
}

@test "test-scripts/setup_elk.sh: waits and prints (N-1) status messages before breaking on the Nth check" {
  _assert_breaks_after_n_checks "${ELK_SCRIPT}" \
    "# --- Step 6: Retrieve and Store Elasticsearch Password ---" \
    "# Change to the base directory" 0 \
    "" \
    "Elasticsearch to start... " 5
}

# --- Scenario: container never reports as running within the loop ---
# The loop should still run through all of its iterations (60, or
# MAX_WAIT_SECONDS for the fleet/kibana scripts) without erroring out, and
# the script should continue past the loop regardless.

_assert_exhausts_all_iterations_when_never_running() {
  local script="$1" start="$2" end="$3" include_end="$4" extra_vars="$5" \
        waiting_msg="$6" max_iterations="$7"

  create_podman_stub 999999
  stub sleep

  local extracted
  extracted="$(extract_block "${script}" "${start}" "${end}" "${include_end}")"
  local harness
  harness="$(build_harness "${extracted}" "${extra_vars}")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  local waiting_count
  waiting_count="$(grep -c "${waiting_msg}.*seconds remaining..." <<< "${output}" || true)"
  [ "${waiting_count}" -eq "${max_iterations}" ]
  [ "$(grep -c "podman inspect" "${CALL_LOG}")" -eq "${max_iterations}" ]
  [ "$(grep -c "^sleep" "${CALL_LOG}")" -eq "${max_iterations}" ]
}

@test "setup_elasticsearch.sh: exhausts all 60 iterations when the container never reports running" {
  _assert_exhausts_all_iterations_when_never_running "${ES_SCRIPT}" \
    "# --- Step 6: Retrieve and Store Elasticsearch Password ---" \
    "# Change to the base directory" 0 \
    'CONTAINER_NAME="es01"' \
    "Elasticsearch to start... " 60
}

@test "setup_fleet_server.sh: exhausts all 60 iterations when the container never reports running" {
  _assert_exhausts_all_iterations_when_never_running "${FLEET_SCRIPT}" \
    "# --- Step 9: Wait for Fleet Server to Start ---" \
    'info "Fleet Server setup complete' 0 \
    'FLEET_SERVER_CONTAINER_NAME="fleet-server"' \
    "Fleet Server to start... " 60
}

@test "setup_kibana.sh: exhausts all 60 iterations when the container never reports running" {
  _assert_exhausts_all_iterations_when_never_running "${KIBANA_SCRIPT}" \
    "# --- Step 7: Wait for Kibana Container to be Running ---" \
    "# --- Step 8: Get Elasticsearch Container IP Address ---" 0 \
    'KIBANA_CONTAINER_NAME="kib01"' \
    "Kibana to start... " 60
}

@test "test-scripts/setup_elk.sh: exhausts all 60 iterations when the container never reports running" {
  _assert_exhausts_all_iterations_when_never_running "${ELK_SCRIPT}" \
    "# --- Step 6: Retrieve and Store Elasticsearch Password ---" \
    "# Change to the base directory" 0 \
    "" \
    "Elasticsearch to start... " 60
}

# --- Scenario: after the loop, exactly one filtered podman ps call is made ---
# setup_elasticsearch.sh, setup_fleet_server.sh, and setup_kibana.sh now
# print a final status line and call `podman ps -a --filter
# name="<container>"` exactly once, after the loop -- not on every
# iteration, as the old code did with an unfiltered `podman ps -a`.

_assert_prints_final_message_and_filtered_ps_once() {
  local script="$1" start="$2" end="$3" include_end="$4" extra_vars="$5" \
        final_msg="$6" container_name="$7"

  create_podman_stub 1
  stub sleep

  local extracted
  extracted="$(extract_block "${script}" "${start}" "${end}" "${include_end}")"
  local harness
  harness="$(build_harness "${extracted}" "${extra_vars}")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"${final_msg}"* ]]
  # Exactly one `podman ps` invocation, and it must be filtered by name.
  [ "$(grep -c "^podman ps" "${CALL_LOG}")" -eq 1 ]
  grep -q "^podman ps -a --filter name=${container_name}\$" "${CALL_LOG}"
}

@test "setup_elasticsearch.sh: prints final status and calls filtered podman ps exactly once after the loop" {
  _assert_prints_final_message_and_filtered_ps_once "${ES_SCRIPT}" \
    "# --- Step 6: Retrieve and Store Elasticsearch Password ---" \
    "# Change to the base directory" 0 \
    'CONTAINER_NAME="es01"' \
    "Elasticsearch container is running." "es01"
}

@test "setup_fleet_server.sh: prints final status and calls filtered podman ps exactly once after the loop" {
  _assert_prints_final_message_and_filtered_ps_once "${FLEET_SCRIPT}" \
    "# --- Step 9: Wait for Fleet Server to Start ---" \
    'info "Fleet Server setup complete' 0 \
    'FLEET_SERVER_CONTAINER_NAME="fleet-server"' \
    "Fleet Server start process complete. You can check the status below:" "fleet-server"
}

@test "setup_kibana.sh: prints final status and calls filtered podman ps exactly once after the loop" {
  _assert_prints_final_message_and_filtered_ps_once "${KIBANA_SCRIPT}" \
    "# --- Step 7: Wait for Kibana Container to be Running ---" \
    "# --- Step 8: Get Elasticsearch Container IP Address ---" 0 \
    'KIBANA_CONTAINER_NAME="kib01"' \
    "Kibana start process waiting complete. You can check the status below:" "kib01"
}

# test-scripts/setup_elk.sh has no podman ps call after its loop (its wait
# block was only changed to add the early-break check, not a post-loop
# status summary), so this documents that no `podman ps` is invoked at all.
@test "test-scripts/setup_elk.sh: does not call podman ps at all around its wait loop" {
  create_podman_stub 1
  stub sleep

  extracted="$(extract_block "${ELK_SCRIPT}" \
    "# --- Step 6: Retrieve and Store Elasticsearch Password ---" \
    "# Change to the base directory")"
  harness="$(build_harness "${extracted}" "")"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  run grep -q "^podman ps" "${CALL_LOG}"
  [ "${status}" -ne 0 ]
}

# --- Regression: the loop only ever polls the correct container name ---
# Ensures the inspect check uses the script's own container-name variable
# (or, for test-scripts/setup_elk.sh, the hard-coded "es01") rather than a
# stale or hard-coded value from another script.

@test "setup_fleet_server.sh: inspect polls the Fleet Server container name, not a hard-coded default" {
  create_podman_stub 1
  stub sleep

  extracted="$(extract_block "${FLEET_SCRIPT}" \
    "# --- Step 9: Wait for Fleet Server to Start ---" \
    'info "Fleet Server setup complete')"
  harness="$(build_harness "${extracted}" 'FLEET_SERVER_CONTAINER_NAME="my-custom-fleet-name"')"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  grep -q "podman inspect -f {{.State.Running}} my-custom-fleet-name" "${CALL_LOG}"
  grep -q "podman ps -a --filter name=my-custom-fleet-name" "${CALL_LOG}"
}

@test "setup_kibana.sh: inspect polls the Kibana container name, not a hard-coded default" {
  create_podman_stub 1
  stub sleep

  extracted="$(extract_block "${KIBANA_SCRIPT}" \
    "# --- Step 7: Wait for Kibana Container to be Running ---" \
    "# --- Step 8: Get Elasticsearch Container IP Address ---")"
  harness="$(build_harness "${extracted}" 'KIBANA_CONTAINER_NAME="my-custom-kibana-name"')"
  run bash "${harness}"

  [ "${status}" -eq 0 ]
  grep -q "podman inspect -f {{.State.Running}} my-custom-kibana-name" "${CALL_LOG}"
  grep -q "podman ps -a --filter name=my-custom-kibana-name" "${CALL_LOG}"
}