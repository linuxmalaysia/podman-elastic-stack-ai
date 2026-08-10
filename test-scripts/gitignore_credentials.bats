#!/usr/bin/env bats
#
# Regression tests for the "# Credentials and secrets" block added to
# .gitignore, which ensures locally generated credential/secret files
# (Gitea DB credentials, generic temp credentials, .env files, and Ansible
# Vault password files) can never be accidentally tracked or committed to
# the repository.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
GITIGNORE="${REPO_ROOT}/.gitignore"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  git init -q "${TEST_TMPDIR}"
  cp "${GITIGNORE}" "${TEST_TMPDIR}/.gitignore"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test ".gitignore exists and is readable" {
  [ -f "${GITIGNORE}" ]
  [ -r "${GITIGNORE}" ]
}

@test ".gitignore declares a 'Credentials and secrets' section" {
  grep -qF -- '# Credentials and secrets' "${GITIGNORE}"
}

@test ".gitignore contains all four new credential/secret patterns" {
  grep -qF -- '*temp_credentials.txt' "${GITIGNORE}"
  grep -qF -- '*gitea_credentials.txt' "${GITIGNORE}"
  grep -qF -- '*.env' "${GITIGNORE}"
  grep -qF -- '*.vault' "${GITIGNORE}"
}

@test ".gitignore retains pre-existing kernel build artifact patterns (no accidental truncation)" {
  # Regression guard: appending the new "Credentials and secrets" block must
  # not have clobbered or removed any of the pre-existing entries.
  grep -qF -- 'Module.symvers' "${GITIGNORE}"
  grep -qF -- 'Mkfile.old' "${GITIGNORE}"
  grep -qF -- 'dkms.conf' "${GITIGNORE}"
  grep -qF -- '*.ko' "${GITIGNORE}"
}

@test ".gitignore: new credential patterns appear after the pre-existing dkms.conf entry" {
  # Guards against the new block being inserted in the middle of the file,
  # which could silently split or duplicate an existing section.
  dkms_line="$(grep -n -F 'dkms.conf' "${GITIGNORE}" | head -1 | cut -d: -f1)"
  creds_line="$(grep -n -F '# Credentials and secrets' "${GITIGNORE}" | head -1 | cut -d: -f1)"
  [ -n "${dkms_line}" ]
  [ -n "${creds_line}" ]
  [ "${creds_line}" -gt "${dkms_line}" ]
}

@test "git actually ignores files matching *temp_credentials.txt" {
  touch "${TEST_TMPDIR}/foo_temp_credentials.txt"
  run git -C "${TEST_TMPDIR}" check-ignore -q "foo_temp_credentials.txt"
  [ "${status}" -eq 0 ]
}

@test "git actually ignores files matching *gitea_credentials.txt" {
  touch "${TEST_TMPDIR}/elk-wolfi_gitea_credentials.txt"
  run git -C "${TEST_TMPDIR}" check-ignore -q "elk-wolfi_gitea_credentials.txt"
  [ "${status}" -eq 0 ]
}

@test "git actually ignores files matching *.env" {
  touch "${TEST_TMPDIR}/production.env"
  run git -C "${TEST_TMPDIR}" check-ignore -q "production.env"
  [ "${status}" -eq 0 ]
}

@test "git actually ignores files matching *.vault" {
  touch "${TEST_TMPDIR}/secrets.vault"
  run git -C "${TEST_TMPDIR}" check-ignore -q "secrets.vault"
  [ "${status}" -eq 0 ]
}

@test "git does NOT ignore unrelated files that merely contain the word 'credentials' or 'env'" {
  # Regression guard against overly broad patterns: files that don't end in
  # the exact suffixes above must still be tracked normally.
  touch "${TEST_TMPDIR}/credentials.txt"
  touch "${TEST_TMPDIR}/environment.txt"
  touch "${TEST_TMPDIR}/README.md"

  run git -C "${TEST_TMPDIR}" check-ignore -q "credentials.txt"
  [ "${status}" -ne 0 ]

  run git -C "${TEST_TMPDIR}" check-ignore -q "environment.txt"
  [ "${status}" -ne 0 ]

  run git -C "${TEST_TMPDIR}" check-ignore -q "README.md"
  [ "${status}" -ne 0 ]
}

@test "git ignores nested credential files matching the patterns regardless of directory depth" {
  mkdir -p "${TEST_TMPDIR}/ansible/elk-wolfi"
  touch "${TEST_TMPDIR}/ansible/elk-wolfi/gitea_credentials.txt"
  run git -C "${TEST_TMPDIR}" check-ignore -q "ansible/elk-wolfi/gitea_credentials.txt"
  [ "${status}" -eq 0 ]
}

@test "git status does not report credential/secret files as untracked" {
  touch "${TEST_TMPDIR}/temp_credentials.txt" "${TEST_TMPDIR}/gitea_credentials.txt" "${TEST_TMPDIR}/db.env" "${TEST_TMPDIR}/pass.vault"
  porcelain="$(cd "${TEST_TMPDIR}" && git status --porcelain)"
  [[ "${porcelain}" != *"temp_credentials.txt"* ]]
  [[ "${porcelain}" != *"gitea_credentials.txt"* ]]
  [[ "${porcelain}" != *"db.env"* ]]
  [[ "${porcelain}" != *"pass.vault"* ]]
}