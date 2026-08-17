#!/usr/bin/env bats
# File: test-scripts/security_credentials.bats
# Description: Verifies that hardcoded passwords have been removed from playbooks and test scripts.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "ansible/setup_elasticsearch.yml does not hardcode ELASTIC_PASSWORD=elastic in WSL2 compose block" {
  run grep -F "ELASTIC_PASSWORD=elastic" "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  [ "$status" -ne 0 ]
}

@test "ansible/setup_elasticsearch.yml uses parameterized elastic_password in WSL2 compose block" {
  run grep -F "ELASTIC_PASSWORD={{ elastic_password }}" "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  [ "$status" -eq 0 ]
}

@test "ansible/setup_elasticsearch.yml does not set elastic_password: 'elastic'" {
  run grep -F 'elastic_password: "elastic"' "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  [ "$status" -ne 0 ]
}

@test "ansible/setup_kibana.yml does not hardcode elasticsearch.password: 'elastic'" {
  run grep -F 'elasticsearch.password: "elastic"' "${REPO_ROOT}/ansible/setup_kibana.yml"
  [ "$status" -ne 0 ]
}

@test "ansible/setup_kibana.yml uses parameterized elasticsearch.password" {
  run grep -F 'elasticsearch.password: "{{ elastic_password }}"' "${REPO_ROOT}/ansible/setup_kibana.yml"
  [ "$status" -eq 0 ]
}

@test "test-scripts/ujian-curl-login.sh does not contain hardcoded password string" {
  run grep -F 'PASSWORD="aOko4p1c-cL10OkJtJ_s"' "${REPO_ROOT}/test-scripts/ujian-curl-login.sh"
  [ "$status" -ne 0 ]
}

@test "test-scripts/ujian-curl-login.sh requires PASSWORD variable" {
  run grep -F 'PASSWORD="${PASSWORD:-}"' "${REPO_ROOT}/test-scripts/ujian-curl-login.sh"
  [ "$status" -eq 0 ]
}

@test "test-scripts/test-elasticsearch.sh does not contain hardcoded ESPASSWORD string" {
  run grep -F 'ESPASSWORD="MMKG16a7=pSOs0TzR87l"' "${REPO_ROOT}/test-scripts/test-elasticsearch.sh"
  [ "$status" -ne 0 ]
}

@test "test-scripts/test-elasticsearch.sh dynamically reads ESPASSWORD or credentials file" {
  run grep -F 'grep "Elastic password set to:"' "${REPO_ROOT}/test-scripts/test-elasticsearch.sh"
  [ "$status" -eq 0 ]
}

# --- Deeper regression coverage for the new random-password-generation flow
# in ansible/setup_elasticsearch.yml (Step 5) and its unification with the
# Step 6 reset flow, which previously special-cased deployment_option ==
# 'wsl2' with a hardcoded "elastic" password. ---

@test "ansible/setup_elasticsearch.yml Step 5 checks for a pre-existing credentials file before generating a password" {
  run grep -F 'name: Check if credentials file already exists' "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  [ "$status" -eq 0 ]
  run grep -F 'register: pre_creds_stat' "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  [ "$status" -eq 0 ]
}

@test "ansible/setup_elasticsearch.yml Step 5 generates a 20-char alphanumeric password when no prior credentials exist" {
  run grep -F "lookup('ansible.builtin.password', '/dev/null chars=ascii_letters,digits length=20')" "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  [ "$status" -eq 0 ]
}

@test "ansible/setup_elasticsearch.yml Step 5 reuses the existing password from disk rather than always regenerating" {
  run grep -F "elastic_password: \"{{ pre_es_password_grep.stdout | trim if (pre_creds_stat.stat.exists and pre_es_password_grep.stdout | trim | length > 0) else lookup" "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  [ "$status" -eq 0 ]
}

@test "ansible/setup_elasticsearch.yml Step 5 password-related tasks are marked no_log to avoid leaking secrets" {
  for task in 'Read existing elastic password if file exists' 'Generate or set initial elastic password fact'; do
    task_line="$(grep -n -F "name: ${task}" "${REPO_ROOT}/ansible/setup_elasticsearch.yml" | head -1 | cut -d: -f1)"
    [ -n "${task_line}" ]
    context="$(sed -n "${task_line},$((task_line + 10))p" "${REPO_ROOT}/ansible/setup_elasticsearch.yml")"
    [[ "${context}" == *"no_log: true"* ]]
  done
}

@test "ansible/setup_elasticsearch.yml Step 5's credentials-file check happens before the WSL 3-Node compose file is written" {
  check_line="$(grep -n -F 'name: Check if credentials file already exists' "${REPO_ROOT}/ansible/setup_elasticsearch.yml" | head -1 | cut -d: -f1)"
  compose_line="$(grep -n -F 'name: Create podman-compose.yml for Elasticsearch (WSL 3-Node Cluster)' "${REPO_ROOT}/ansible/setup_elasticsearch.yml" | head -1 | cut -d: -f1)"
  [ -n "${check_line}" ]
  [ -n "${compose_line}" ]
  [ "${check_line}" -lt "${compose_line}" ]
}

@test "ansible/setup_elasticsearch.yml no longer contains a dedicated WSL2 static-password task" {
  run grep -F 'name: Set static password for WSL2 deployment option' "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  [ "$status" -ne 0 ]
}

@test "ansible/setup_elasticsearch.yml no longer contains a dedicated WSL2 credentials-file initializer task" {
  run grep -F 'name: Initialize temporary credentials file (WSL2)' "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  [ "$status" -ne 0 ]
}

@test "ansible/setup_elasticsearch.yml Step 6 password-reset flow is unified: no wsl2-specific 'when' guards remain" {
  # Regression guard: before this fix, nearly every task in Step 6 carried
  # an additional 'deployment_option != wsl2' condition (or its inverse),
  # which is exactly what allowed the WSL2 path to skip password rotation
  # entirely. The whole Step 6 block, from its header to the start of
  # Step 7, must no longer reference 'wsl2' at all.
  step6_block="$(awk '
    /name: "Step 6 - Retrieve and Store Elasticsearch Password"/ {capture=1}
    capture && /name: "Step 7 - Copy SSL Certificate"/ {exit}
    capture {print}
  ' "${REPO_ROOT}/ansible/setup_elasticsearch.yml")"
  [ -n "${step6_block}" ]
  [[ "${step6_block}" != *"wsl2"* ]]
}

@test "ansible/setup_elasticsearch.yml 'Set existing password fact' falls back to the Step 5 elastic_password, not an empty default" {
  # Previously this task's else-branch (when no credentials file/grep match
  # exists) hardcoded an empty string. It now falls back to the
  # already-generated elastic_password fact from Step 5 so a freshly
  # generated random password is not silently discarded before the
  # first-ever password-reset check.
  run grep -F "existing_elastic_password: \"{{ es_password_grep.stdout | trim if (creds_file_stat.stat.exists and es_password_grep.stdout is defined) else (elastic_password | default('')) }}\"" "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  [ "$status" -eq 0 ]
}

@test "ansible/setup_elasticsearch.yml Step 6 tasks retain their guarding 'when' conditions after wsl2 clauses were dropped" {
  # Confirms the wsl2-condition removal didn't also strip the *other*,
  # still-required guards (e.g. password_reset_needed) alongside it.
  grep -qF -- 'when: creds_file_stat.stat.exists' "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  grep -qF -- 'when: password_reset_needed' "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  grep -qF -- 'when: not password_reset_needed' "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
}

# --- Functional test of the embedded password-extraction shell pipeline ---
# (used both by Step 5's "pre_es_password_grep" and Step 6's
# "es_password_grep" tasks, and mirrored in test-elasticsearch.sh).

_run_elastic_password_extraction_pipeline() {
  local fixture="$1"
  grep "Elastic password set to:" "${fixture}" | sed 's/.*Elastic password set to: //' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

@test "elastic password-extraction pipeline parses a well-formed credentials file" {
  fixture="${BATS_TEST_TMPDIR:-$(mktemp -d)}/creds.txt"
  cat > "${fixture}" <<'EOF'
--- Step 6: Retrieve and Store Elasticsearch Password ---
2024-01-01T00:00:00Z
Elastic password set to: Sup3rSecretPass123
EOF
  result="$(_run_elastic_password_extraction_pipeline "${fixture}")"
  [ "${result}" = "Sup3rSecretPass123" ]
}

@test "elastic password-extraction pipeline strips surrounding whitespace" {
  fixture="${BATS_TEST_TMPDIR:-$(mktemp -d)}/creds_ws.txt"
  printf 'Elastic password set to:   Sp4cey   \n' > "${fixture}"
  result="$(_run_elastic_password_extraction_pipeline "${fixture}")"
  [ "${result}" = "Sp4cey" ]
}

@test "elastic password-extraction pipeline yields empty output when the field is absent" {
  fixture="${BATS_TEST_TMPDIR:-$(mktemp -d)}/creds_missing.txt"
  echo "no password here" > "${fixture}"
  result="$(_run_elastic_password_extraction_pipeline "${fixture}" || true)"
  [ -z "${result}" ]
}

@test "ansible/setup_kibana.yml elasticsearch.password templating is only applied in the wsl2 blockinfile task" {
  # Regression guard: the parameterization must live inside the same
  # blockinfile task/when-guard as before, not accidentally introduced
  # elsewhere (e.g. unconditionally for every deployment option).
  line="$(grep -n -F 'elasticsearch.password: "{{ elastic_password }}"' "${REPO_ROOT}/ansible/setup_kibana.yml" | head -1 | cut -d: -f1)"
  [ -n "${line}" ]
  context="$(sed -n "$((line - 5)),$((line + 5))p" "${REPO_ROOT}/ansible/setup_kibana.yml")"
  [[ "${context}" == *"elasticsearch.username: \"elastic\""* ]]
  when_line="$(sed -n "$((line + 1)),$((line + 6))p" "${REPO_ROOT}/ansible/setup_kibana.yml")"
  [[ "${when_line}" == *"when: deployment_option == 'wsl2'"* ]]
}
