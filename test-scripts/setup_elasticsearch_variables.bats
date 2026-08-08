#!/usr/bin/env bats
#
# Regression tests for the "--- Variables ---" block in
# setup_elasticsearch.sh, specifically covering the removal of the unused
# KIBANA_IMAGE variable (setup_elasticsearch.sh never starts/pulls a Kibana
# container itself -- that responsibility lives in setup_kibana.sh /
# test-scripts/setup_elk.sh, which each define and use their own
# KIBANA_IMAGE variable).
#
# These tests guard against:
#   1. KIBANA_IMAGE (or a reference to the Kibana image path) being
#      reintroduced into setup_elasticsearch.sh without being used.
#   2. The remaining variables in the block being accidentally broken,
#      renamed, or reordered by the removal.
#   3. The script losing valid bash syntax as a result of editing the
#      Variables block.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ES_SCRIPT="${REPO_ROOT}/setup_elasticsearch.sh"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

# Extracts the "--- Variables ---" block from setup_elasticsearch.sh (i.e.
# everything from the "# --- Variables ---" marker up to, but not
# including, the "# --- Helper Functions ---" marker that follows it).
extract_variables_block() {
  awk '
    /^# --- Variables ---$/ {capture=1; next}
    /^# --- Helper Functions ---$/ {exit}
    capture {print}
  ' "${ES_SCRIPT}"
}

@test "setup_elasticsearch.sh exists and is readable" {
  [ -f "${ES_SCRIPT}" ]
  [ -r "${ES_SCRIPT}" ]
}

@test "setup_elasticsearch.sh has valid bash syntax" {
  run bash -n "${ES_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "setup_elasticsearch.sh no longer declares an unused KIBANA_IMAGE variable" {
  # Regression guard: KIBANA_IMAGE was removed from this script because it
  # was dead code (setup_elasticsearch.sh never references it).
  run grep -E '^[[:space:]]*KIBANA_IMAGE=' "${ES_SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "setup_elasticsearch.sh does not reference KIBANA_IMAGE anywhere" {
  run grep -F 'KIBANA_IMAGE' "${ES_SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "setup_elasticsearch.sh does not reference the Kibana docker image path" {
  # Even though the script legitimately mentions "Kibana" in the
  # enrollment-token step, it must not reference the Kibana *image* path,
  # since it never pulls/starts a Kibana container.
  run grep -F 'docker.elastic.co/kibana/kibana' "${ES_SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "setup_elasticsearch.sh Variables block retains exactly the expected variable names, in order" {
  extracted="$(extract_variables_block)"

  # Collect the names of variables assigned in the block, in order, e.g.
  # 'ELK_VERSION="9.4.4"' -> 'ELK_VERSION', joined by spaces so we can do a
  # simple string comparison (avoids relying on process substitution).
  var_names="$(echo "${extracted}" | grep -oE '^[A-Z_][A-Z0-9_]*=' | sed 's/=$//' | tr '\n' ' ')"

  expected="ELK_VERSION ELK_BASE_DIR ELK_DIR CERT_DIR CONTAINER_NAME DATA_DIR ELASTICSEARCH_IMAGE NETWORK_NAME TEMP_CREDENTIALS_FILE "

  [ "${var_names}" = "${expected}" ]
}

@test "setup_elasticsearch.sh Variables block: ELASTICSEARCH_IMAGE is immediately followed by NETWORK_NAME (no gap left by removed line)" {
  extracted="$(extract_variables_block)"
  # grep -A1 prints the matching line plus the one after it; the second
  # line of that output must be the NETWORK_NAME assignment, proving no
  # stray line (e.g. a resurrected KIBANA_IMAGE) sits between them.
  next_line="$(echo "${extracted}" | grep -A1 -F 'ELASTICSEARCH_IMAGE=' | tail -n1)"
  [ "${next_line}" = 'NETWORK_NAME="elastic"' ]
}

@test "setup_elasticsearch.sh Variables block sources cleanly and yields correct values, with KIBANA_IMAGE left unset" {
  block="$(extract_variables_block)"
  harness="${TEST_TMPDIR}/harness.sh"
  {
    echo '#!/usr/bin/env bash'
    echo 'SCRIPT_DIR="/tmp/fake-script-dir"'
    echo "${block}"
    echo 'echo "ELK_VERSION=${ELK_VERSION}"'
    echo 'echo "ELK_BASE_DIR=${ELK_BASE_DIR}"'
    echo 'echo "ELK_DIR=${ELK_DIR}"'
    echo 'echo "CERT_DIR=${CERT_DIR}"'
    echo 'echo "CONTAINER_NAME=${CONTAINER_NAME}"'
    echo 'echo "DATA_DIR=${DATA_DIR}"'
    echo 'echo "ELASTICSEARCH_IMAGE=${ELASTICSEARCH_IMAGE}"'
    echo 'echo "NETWORK_NAME=${NETWORK_NAME}"'
    echo 'echo "TEMP_CREDENTIALS_FILE=${TEMP_CREDENTIALS_FILE}"'
    echo 'if [ -z "${KIBANA_IMAGE+x}" ]; then echo "KIBANA_IMAGE_UNSET=true"; else echo "KIBANA_IMAGE_UNSET=false"; fi'
  } > "${harness}"
  chmod +x "${harness}"

  run bash "${harness}"
  [ "${status}" -eq 0 ]

  [[ "${output}" == *"ELK_VERSION=9.4.4"* ]]
  [[ "${output}" == *"ELK_BASE_DIR=/tmp/fake-script-dir"* ]]
  [[ "${output}" == *"ELK_DIR=/tmp/fake-script-dir/elk-wolfi"* ]]
  [[ "${output}" == *"CERT_DIR=/tmp/fake-script-dir/elk-wolfi/certs"* ]]
  [[ "${output}" == *"CONTAINER_NAME=es01"* ]]
  [[ "${output}" == *"DATA_DIR=/data/es01"* ]]
  [[ "${output}" == *"ELASTICSEARCH_IMAGE=docker.elastic.co/elasticsearch/elasticsearch-wolfi:9.4.4"* ]]
  [[ "${output}" == *"NETWORK_NAME=elastic"* ]]
  [[ "${output}" == *"TEMP_CREDENTIALS_FILE=/tmp/fake-script-dir/elk-wolfi/temp_credentials.txt"* ]]
  [[ "${output}" == *"KIBANA_IMAGE_UNSET=true"* ]]
}

@test "setup_elasticsearch.sh still legitimately mentions Kibana in the enrollment-token step (sanity check)" {
  # Ensures our KIBANA_IMAGE-focused assertions above aren't accidentally
  # stripping out the legitimate, unrelated Kibana enrollment-token logic.
  grep -qF 'Retrieve and Clean Kibana Enrollment Token' "${ES_SCRIPT}"
  grep -qF 'elasticsearch-create-enrollment-token -s kibana' "${ES_SCRIPT}"
}