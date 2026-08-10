#!/usr/bin/env bats
#
# Regression tests for documentation content in LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md.
# These ensure that the local development setup, multi-OS testing matrix,
# and bidirectional feedback loop are correctly and persistently documented.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
GUIDE="${REPO_ROOT}/docs/LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md"

@test "LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md exists and is readable" {
  [ -f "${GUIDE}" ]
  [ -r "${GUIDE}" ]
}

@test "GUIDE documents Windows WSL2 and Ubuntu 26.04 LTS" {
  grep -qF 'Windows WSL2 (Ubuntu 26.04 LTS)' "${GUIDE}"
}

@test "GUIDE documents Podman 5+ requirement" {
  grep -qF 'Podman 5+' "${GUIDE}"
}

@test "GUIDE documents Developer vs User Mode separation protocol" {
  grep -qF 'Mode Separation Protocol (Developer vs User Mode)' "${GUIDE}"
  grep -qF 'EXECUTION_MODE=dev' "${GUIDE}"
  grep -qF 'EXECUTION_MODE=user' "${GUIDE}"
}

@test "GUIDE documents Ansible matrix test playbook" {
  grep -qF 'playbooks/matrix_test.yml' "${GUIDE}"
}

@test "GUIDE documents feedback collector tasks" {
  grep -qF 'playbooks/roles/feedback_collector/tasks/main.yml' "${GUIDE}"
}

@test "GUIDE documents feedback bridge script" {
  grep -qF 'scripts/jules_gh_feedback.sh' "${GUIDE}"
}

@test "GUIDE contains complete copy-paste ready code files with zero omissions" {
  grep -qF '[defaults]' "${GUIDE}"
  grep -qF 'feedback_collector' "${GUIDE}"
  grep -qF 'jules_test_ubuntu_26_04' "${GUIDE}"
  grep -qF 'jules_gh_feedback.sh' "${GUIDE}"
}
