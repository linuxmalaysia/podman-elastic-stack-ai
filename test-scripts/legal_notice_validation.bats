#!/usr/bin/env bats
# ==============================================================================
# Script      : legal_notice_validation.bats
# Description : Unit and Integration tests for Legal Notice OKF & Footer standards
# Author      : Jules (AI Agent)
# Date        : 2026-07-12
# ==============================================================================

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
LEGAL_NOTICE_DOC="${REPO_ROOT}/docs/legal-notice.md"
MKDOCS_YML="${REPO_ROOT}/mkdocs.yml"

@test "docs/legal-notice.md exists and is readable" {
  [ -f "${LEGAL_NOTICE_DOC}" ]
  [ -r "${LEGAL_NOTICE_DOC}" ]
}

@test "docs/legal-notice.md contains valid OKF standard front-matter metadata" {
  # Verify standard OKF front-matter exists
  grep -qF 'okf_version: 0.1' "${LEGAL_NOTICE_DOC}"
  grep -qF 'type: documentation' "${LEGAL_NOTICE_DOC}"
  grep -qF 'title: "legal-notice.md"' "${LEGAL_NOTICE_DOC}"
  grep -qF 'resource: file:///docs/legal-notice.md' "${LEGAL_NOTICE_DOC}"
}

@test "docs/legal-notice.md documents Educational and Training Purpose" {
  grep -qF '## 1. Educational and Training Purpose' "${LEGAL_NOTICE_DOC}"
  grep -qF 'strictly for training, educational, and planning proposal purposes only' "${LEGAL_NOTICE_DOC}"
}

@test "docs/legal-notice.md documents Reliance on Critical Assumptions" {
  grep -qF '## 2. Reliance on Critical Assumptions' "${LEGAL_NOTICE_DOC}"
  grep -qF 'based on assumptions' "${LEGAL_NOTICE_DOC}"
}

@test "docs/legal-notice.md documents Privacy Statement & Data Protection" {
  grep -qF '## 3. Privacy Statement & Data Protection' "${LEGAL_NOTICE_DOC}"
  grep -qF 'We are deeply committed to privacy and data protection.' "${LEGAL_NOTICE_DOC}"
  grep -qF 'Anonymised Metadata' "${LEGAL_NOTICE_DOC}"
  grep -qF 'Zero Real-World Storage' "${LEGAL_NOTICE_DOC}"
}

@test "docs/legal-notice.md documents Assumption of Risk & Liability Disclaimer" {
  grep -qF '## 4. Assumption of Risk & Liability Disclaimer' "${LEGAL_NOTICE_DOC}"
  grep -qF 'Use of this project, its code, and its documents is at your own risk.' "${LEGAL_NOTICE_DOC}"
  grep -qF 'We are not going to be responsible' "${LEGAL_NOTICE_DOC}"
  grep -qF 'contributors, authors, and organisations shall not be held liable' "${LEGAL_NOTICE_DOC}"
}

@test "mkdocs.yml includes the global legal notice link in the copyright footer standard" {
  grep -qF 'copyright:' "${MKDOCS_YML}"
  grep -qF 'legal-notice/' "${MKDOCS_YML}"
  grep -qF 'Disclaimer of Liability' "${MKDOCS_YML}"
}
