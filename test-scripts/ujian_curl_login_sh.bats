#!/usr/bin/env bats
# File: test-scripts/ujian_curl_login_sh.bats
# Description: Tests for test-scripts/ujian-curl-login.sh, which replaced a
# hardcoded PASSWORD value with one that must be supplied via the PASSWORD
# environment variable (the script now aborts with a clear error instead of
# silently using a baked-in credential).

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="${REPO_ROOT}/test-scripts/ujian-curl-login.sh"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  STUB_BIN="${TEST_TMPDIR}/bin"
  mkdir -p "${STUB_BIN}"
  CALL_LOG="${TEST_TMPDIR}/calls.log"
  : > "${CALL_LOG}"

  # Stub curl so no real request ever reaches httpbin.org; it just records
  # how it was invoked.
  cat > "${STUB_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${CALL_LOG}"
exit 0
EOF
  chmod +x "${STUB_BIN}/curl"
  export PATH="${STUB_BIN}:${PATH}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "ujian-curl-login.sh exists, is readable, and has valid bash syntax" {
  [ -f "${SCRIPT}" ]
  [ -r "${SCRIPT}" ]
  run bash -n "${SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "ujian-curl-login.sh no longer hardcodes the old leaked PASSWORD value" {
  run grep -F 'aOko4p1c-cL10OkJtJ_s' "${SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "ujian-curl-login.sh no longer contains a hardcoded PASSWORD= literal assignment" {
  run grep -E '^PASSWORD="[^$]' "${SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "fails with a helpful error and exit code 1 when PASSWORD is unset" {
  run env -u PASSWORD bash "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Error: PASSWORD environment variable is not set."* ]]
  [[ "${output}" == *"Usage: PASSWORD='your_password' USERNAME='testuser'"* ]]
  # curl must never be invoked when we bail out before that point.
  [ ! -s "${CALL_LOG}" ]
}

@test "fails with exit code 1 when PASSWORD is set but empty" {
  run env PASSWORD="" bash "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Error: PASSWORD environment variable is not set."* ]]
  [ ! -s "${CALL_LOG}" ]
}

@test "defaults USERNAME to 'testuser' when USERNAME is not set" {
  run env -u USERNAME PASSWORD="mypassword" bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"https://httpbin.org/basic-auth/testuser/mypassword"* ]]
}

@test "honors a custom USERNAME when provided" {
  run env USERNAME="customuser" PASSWORD="mypassword" bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"https://httpbin.org/basic-auth/customuser/mypassword"* ]]
}

@test "builds the correct base64-encoded Basic Authorization header and invokes curl with it" {
  run env USERNAME="testuser" PASSWORD="mypassword" bash "${SCRIPT}"
  [ "${status}" -eq 0 ]

  expected_b64="$(printf '%s' "testuser:mypassword" | base64)"
  grep -qF -- "Authorization: Basic ${expected_b64}" "${CALL_LOG}"
}

@test "invokes curl exactly once, targeting the expected basic-auth URL" {
  run env USERNAME="testuser" PASSWORD="mypassword" bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(wc -l < "${CALL_LOG}")" -eq 1 ]
  grep -qF -- "https://httpbin.org/basic-auth/testuser/mypassword" "${CALL_LOG}"
  grep -qF -- "-v" "${CALL_LOG}"
}

@test "a different PASSWORD value produces a different base64 Authorization header" {
  run env USERNAME="testuser" PASSWORD="anotherPass!" bash "${SCRIPT}"
  [ "${status}" -eq 0 ]

  expected_b64="$(printf '%s' "testuser:anotherPass!" | base64)"
  grep -qF -- "Authorization: Basic ${expected_b64}" "${CALL_LOG}"

  wrong_b64="$(printf '%s' "testuser:mypassword" | base64)"
  run grep -qF -- "${wrong_b64}" "${CALL_LOG}"
  [ "${status}" -ne 0 ]
}