#!/usr/bin/env bats
# File: test-scripts/security_credentials.bats
# setup determines the repository root directory from the Bats test file location.

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
