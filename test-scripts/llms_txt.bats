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
    "docs/WSL-3NODE-CLUSTER-GUIDE.md"
    "docs/GITEA_GUIDE.md"
  )
  for rel_path in "${rel_paths[@]}"; do
    [ -f "${REPO_ROOT}/${rel_path}" ]
  done
}