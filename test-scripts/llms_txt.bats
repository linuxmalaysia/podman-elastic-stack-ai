#!/usr/bin/env bats
#
# Regression tests for llms.txt, ensuring the "Core Documentation" links
# were updated to point at the relocated docs/ directory guide files, that
# the new GITEA_GUIDE.md entry was added, and that no stale root-relative
# links to the relocated files remain.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
LLMS_TXT="${REPO_ROOT}/llms.txt"

@test "llms.txt exists and is readable" {
  [ -f "${LLMS_TXT}" ]
  [ -r "${LLMS_TXT}" ]
}

@test "llms.txt links the relocated guide docs under the docs/ directory" {
  grep -qF '[INSTALL.md](docs/INSTALL.md):' "${LLMS_TXT}"
  grep -qF '[PLAYBOOKS.md](docs/PLAYBOOKS.md):' "${LLMS_TXT}"
  grep -qF '[LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md](docs/LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md):' "${LLMS_TXT}"
  grep -qF '[DOCS_MATRIX_TELEMETRY.md](docs/DOCS_MATRIX_TELEMETRY.md):' "${LLMS_TXT}"
  grep -qF '[WSL-3NODE-CLUSTER-GUIDE.md](docs/WSL-3NODE-CLUSTER-GUIDE.md):' "${LLMS_TXT}"
  grep -qF '[PODMAN_ROOTLESS.md](docs/PODMAN_ROOTLESS.md):' "${LLMS_TXT}"
  grep -qF '[ANSIBLE_FQCN.md](docs/ANSIBLE_FQCN.md):' "${LLMS_TXT}"
  grep -qF '[ANSIBLE_ADOPTION_REVIEW.md](docs/ANSIBLE_ADOPTION_REVIEW.md):' "${LLMS_TXT}"
  grep -qF '[ANSIBLE_PLAYBOOK_MAP.md](docs/ANSIBLE_PLAYBOOK_MAP.md):' "${LLMS_TXT}"
  grep -qF '[SOP_KNOWLEDGE_FIRST_DISCOVERY.md](docs/SOP_KNOWLEDGE_FIRST_DISCOVERY.md):' "${LLMS_TXT}"
}

@test "llms.txt documents the new GITEA_GUIDE.md entry under docs/" {
  grep -qF '[GITEA_GUIDE.md](docs/GITEA_GUIDE.md): Sovereign Gitea Deployment and Security Operations Guide.' "${LLMS_TXT}"
}

@test "llms.txt still links README.md at the repository root (not relocated)" {
  grep -qF '[README.md](README.md):' "${LLMS_TXT}"
}

@test "llms.txt no longer contains stale root-relative links to the relocated guide docs" {
  # Regression guard: prior to this PR, these five files were linked
  # without the docs/ prefix (e.g. "[INSTALL.md](INSTALL.md)"). Ensure the
  # outdated root-relative link form is gone for each relocated file.
  for doc in INSTALL.md PLAYBOOKS.md LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md DOCS_MATRIX_TELEMETRY.md WSL-3NODE-CLUSTER-GUIDE.md; do
    run grep -qF "](${doc}):" "${LLMS_TXT}"
    [ "${status}" -ne 0 ]
  done
}

@test "llms.txt GITEA_GUIDE.md entry appears after the WSL-3NODE-CLUSTER-GUIDE.md entry" {
  local wsl_line gitea_line
  wsl_line="$(grep -n -F '[WSL-3NODE-CLUSTER-GUIDE.md]' "${LLMS_TXT}" | head -1 | cut -d: -f1)"
  gitea_line="$(grep -n -F '[GITEA_GUIDE.md]' "${LLMS_TXT}" | head -1 | cut -d: -f1)"
  [ -n "${wsl_line}" ]
  [ -n "${gitea_line}" ]
  [ "${gitea_line}" -gt "${wsl_line}" ]
}

@test "llms.txt Core Documentation links resolve to files that actually exist in the repository" {
  local rel_paths=(
    "README.md"
    "docs/INSTALL.md"
    "docs/PLAYBOOKS.md"
    "docs/LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md"
    "docs/DOCS_MATRIX_TELEMETRY.md"
    "docs/PODMAN_ROOTLESS.md"
    "docs/ANSIBLE_FQCN.md"
    "docs/ANSIBLE_ADOPTION_REVIEW.md"
    "docs/ANSIBLE_PLAYBOOK_MAP.md"
    "docs/SOP_KNOWLEDGE_FIRST_DISCOVERY.md"
    "docs/WSL-3NODE-CLUSTER-GUIDE.md"
    "docs/GITEA_GUIDE.md"
    "docs/ELASTIC_9_UPGRADE_PLAN.md"
  )
  for rel_path in "${rel_paths[@]}"; do
    [ -f "${REPO_ROOT}/${rel_path}" ]
  done
}

# Regression tests for the two newest Core Documentation entries: the
# REFERENCE_TUNING.md tuning-resource compilation and the new
# legal-notice.md Legal Notice & Disclaimer document, both linked under
# the docs/ directory and appended after the existing GITEA_GUIDE.md entry.

@test "llms.txt documents the new REFERENCE_TUNING.md entry under docs/" {
  grep -qF '[REFERENCE_TUNING.md](docs/REFERENCE_TUNING.md): Compilation of reference tuning URLs and WSL2/kernel optimization parameters.' "${LLMS_TXT}"
}

@test "llms.txt documents the new legal-notice.md entry under docs/" {
  grep -qF '[legal-notice.md](docs/legal-notice.md): Legal Notice, Privacy Policy, Critical Assumptions, and Assumption of Risk / Liability Disclaimer.' "${LLMS_TXT}"
}

@test "llms.txt lists REFERENCE_TUNING.md and legal-notice.md after the GITEA_GUIDE.md entry, with legal-notice.md last" {
  local gitea_line reference_line legal_line
  gitea_line="$(grep -n -F '[GITEA_GUIDE.md]' "${LLMS_TXT}" | head -1 | cut -d: -f1)"
  reference_line="$(grep -n -F '[REFERENCE_TUNING.md]' "${LLMS_TXT}" | head -1 | cut -d: -f1)"
  legal_line="$(grep -n -F '[legal-notice.md]' "${LLMS_TXT}" | head -1 | cut -d: -f1)"
  [ -n "${gitea_line}" ]
  [ -n "${reference_line}" ]
  [ -n "${legal_line}" ]
  [ "${reference_line}" -gt "${gitea_line}" ]
  [ "${legal_line}" -gt "${reference_line}" ]
}

@test "llms.txt's REFERENCE_TUNING.md and legal-notice.md link targets actually exist in docs/" {
  [ -f "${REPO_ROOT}/docs/REFERENCE_TUNING.md" ]
  [ -f "${REPO_ROOT}/docs/legal-notice.md" ]
  [ -f "${REPO_ROOT}/docs/ELASTIC_9_UPGRADE_PLAN.md" ]
}

@test "llms.txt does not link legal-notice.md or REFERENCE_TUNING.md at the repository root (docs/ prefix required)" {
  run grep -qF '](legal-notice.md):' "${LLMS_TXT}"
  [ "${status}" -ne 0 ]
  run grep -qF '](REFERENCE_TUNING.md):' "${LLMS_TXT}"
  [ "${status}" -ne 0 ]
}

@test "llms.txt has exactly one legal-notice.md entry (no duplicates)" {
  local count
  count="$(grep -cF '[legal-notice.md]' "${LLMS_TXT}")"
  [ "${count}" -eq 1 ]
}

@test "llms.txt has the exact entry for ELASTIC_9_UPGRADE_PLAN.md" {
  grep -qF '[ELASTIC_9_UPGRADE_PLAN.md](docs/ELASTIC_9_UPGRADE_PLAN.md): Comprehensive Guide and 2-Week Plan for Upgrading the Podman-based Elastic Stack to Version 9.5.0.' "${LLMS_TXT}"
}