#!/usr/bin/env bats
# File: test-scripts/security_credentials.bats
# Description: Verifies that hardcoded passwords have been removed from playbooks and test scripts.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "ansible/setup_elasticsearch.yml does not hardcode non-empty credential assignments" {
  run grep -E -i 'ELASTIC_PASSWORD\s*=\s*["'\''][^"'\'']{1,100}["'\'']|elastic_password:\s*["'\''][^"'\'']{1,100}["' ']' "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  [ "$status" -ne 0 ]
}

@test "ansible/setup_elasticsearch.yml uses parameterized elastic_password in WSL2 compose block" {
  run grep -F "ELASTIC_PASSWORD={{ elastic_password }}" "${REPO_ROOT}/ansible/setup_elasticsearch.yml"
  [ "$status" -eq 0 ]
}

@test "ansible/setup_kibana.yml does not hardcode non-empty elasticsearch.password assignment" {
  run grep -E -i 'elasticsearch\.password:\s*["'\''][^"'\'']{1,100}["' ']' "${REPO_ROOT}/ansible/setup_kibana.yml"
  [ "$status" -ne 0 ]
}

@test "ansible/setup_kibana.yml uses parameterized elasticsearch.password" {
  run grep -F 'elasticsearch.password: "{{ elastic_password }}"' "${REPO_ROOT}/ansible/setup_kibana.yml"
  [ "$status" -eq 0 ]
}

@test "test-scripts/ujian-curl-login.sh does not contain hardcoded PASSWORD assignment" {
  run grep -E -i 'PASSWORD\s*=\s*["'\''][^"'\'']{1,100}["' ']' "${REPO_ROOT}/test-scripts/ujian-curl-login.sh"
  [ "$status" -ne 0 ]
}

@test "test-scripts/ujian-curl-login.sh supports PASSWORD environment variable" {
  run grep -F 'PASSWORD="${PASSWORD:-}"' "${REPO_ROOT}/test-scripts/ujian-curl-login.sh"
  [ "$status" -eq 0 ]
}

@test "test-scripts/test-elasticsearch.sh does not contain hardcoded ESPASSWORD assignment" {
  run grep -E -i 'ESPASSWORD\s*=\s*["'\''][^"'\'']{1,100}["' ']' "${REPO_ROOT}/test-scripts/test-elasticsearch.sh"
  [ "$status" -ne 0 ]
}

@test "test-scripts/test-elasticsearch.sh dynamically reads ESPASSWORD or credentials file" {
  run grep -F 'grep "Elastic password set to:"' "${REPO_ROOT}/test-scripts/test-elasticsearch.sh"
  [ "$status" -eq 0 ]
}
