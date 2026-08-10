#!/usr/bin/env bats
#
# Regression tests for CHANGELOG.md, specifically the "Changed" entries
# documenting the docs/ directory reorganization: relocating the detailed
# guide documentation files out of the repository root into docs/, while
# correcting the earlier entry's stale "INSTALL.md" reference to
# "docs/INSTALL.md".

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CHANGELOG="${REPO_ROOT}/CHANGELOG.md"

@test "CHANGELOG.md exists and is readable" {
  [ -f "${CHANGELOG}" ]
  [ -r "${CHANGELOG}" ]
}

@test "CHANGELOG.md documents the 9.4.4 version upgrade" {
  grep -qF 'Default Elastic Stack version upgraded from `8.17.4` to `9.4.4`' "${CHANGELOG}"
}

@test "CHANGELOG.md references docs/INSTALL.md (not the stale root-relative INSTALL.md) for the version/WSL2 doc update entry" {
  grep -qF 'Updated documentation in `README.md` and `docs/INSTALL.md` to reference version 9.4.4 and the new Windows 11 WSL2 command workflow.' "${CHANGELOG}"
}

@test "CHANGELOG.md no longer references the stale root-relative 'INSTALL.md' wording for the doc-update entry" {
  # Regression guard: prior to this PR, this entry referenced bare
  # "INSTALL.md" (without the docs/ prefix), which became inaccurate once
  # the file was relocated.
  run grep -F 'Updated documentation in `README.md` and `INSTALL.md`' "${CHANGELOG}"
  [ "${status}" -ne 0 ]
}

@test "CHANGELOG.md documents the docs/ directory reorganization entry" {
  grep -qF 'Reorganized project structure by relocating all detailed guide documentation files' "${CHANGELOG}"
  grep -qF '`INSTALL.md`' "${CHANGELOG}"
  grep -qF '`PLAYBOOKS.md`' "${CHANGELOG}"
  grep -qF '`LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md`' "${CHANGELOG}"
  grep -qF 'to the `docs/` directory' "${CHANGELOG}"
}

@test "CHANGELOG.md clarifies that README.md, HISTORY.md, and CHANGELOG.md remain in the root directory" {
  grep -qF 'while maintaining `README.md`, `HISTORY.md`, and `CHANGELOG.md` in the root directory' "${CHANGELOG}"
}

@test "CHANGELOG.md reorganization entry appears after the version/WSL2 doc update entry" {
  local doc_update_line reorg_line
  doc_update_line="$(grep -n -F 'Updated documentation in `README.md` and `docs/INSTALL.md`' "${CHANGELOG}" | head -1 | cut -d: -f1)"
  reorg_line="$(grep -n -F 'Reorganized project structure by relocating' "${CHANGELOG}" | head -1 | cut -d: -f1)"
  [ -n "${doc_update_line}" ]
  [ -n "${reorg_line}" ]
  [ "${reorg_line}" -gt "${doc_update_line}" ]
}

@test "CHANGELOG.md retains the pre-existing Added section entries (no accidental truncation)" {
  grep -qF 'Comprehensive Windows 11 WSL2 deployment guide for Ubuntu 26.04 and AlmaLinux 10.' "${CHANGELOG}"
  grep -qF 'Dedicated `HISTORY.md` detailing project milestones and the transition from bash to Ansible.' "${CHANGELOG}"
  grep -qF 'Dedicated `CHANGELOG.md` file.' "${CHANGELOG}"
}