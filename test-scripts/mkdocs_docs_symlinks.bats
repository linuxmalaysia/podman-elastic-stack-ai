#!/usr/bin/env bats
#
# Regression tests for the docs/index.md, docs/CHANGELOG.md, and
# docs/HISTORY.md symlinks, which expose the repository-root README.md,
# CHANGELOG.md, and HISTORY.md files to the MkDocs build (whose docs_dir
# defaults to docs/) without duplicating their content.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
DOCS_DIR="${REPO_ROOT}/docs"

@test "docs/index.md is a symlink pointing to ../README.md" {
  [ -L "${DOCS_DIR}/index.md" ]
  [ "$(readlink "${DOCS_DIR}/index.md")" = "../README.md" ]
}

@test "docs/CHANGELOG.md is a symlink pointing to ../CHANGELOG.md" {
  [ -L "${DOCS_DIR}/CHANGELOG.md" ]
  [ "$(readlink "${DOCS_DIR}/CHANGELOG.md")" = "../CHANGELOG.md" ]
}

@test "docs/HISTORY.md is a symlink pointing to ../HISTORY.md" {
  [ -L "${DOCS_DIR}/HISTORY.md" ]
  [ "$(readlink "${DOCS_DIR}/HISTORY.md")" = "../HISTORY.md" ]
}

@test "docs/index.md symlink resolves to an existing, readable file" {
  [ -f "${DOCS_DIR}/index.md" ]
  [ -r "${DOCS_DIR}/index.md" ]
}

@test "docs/CHANGELOG.md symlink resolves to an existing, readable file" {
  [ -f "${DOCS_DIR}/CHANGELOG.md" ]
  [ -r "${DOCS_DIR}/CHANGELOG.md" ]
}

@test "docs/HISTORY.md symlink resolves to an existing, readable file" {
  [ -f "${DOCS_DIR}/HISTORY.md" ]
  [ -r "${DOCS_DIR}/HISTORY.md" ]
}

@test "docs/index.md content is identical to the root README.md content" {
  diff -q "${DOCS_DIR}/index.md" "${REPO_ROOT}/README.md"
}

@test "docs/CHANGELOG.md content is identical to the root CHANGELOG.md content" {
  diff -q "${DOCS_DIR}/CHANGELOG.md" "${REPO_ROOT}/CHANGELOG.md"
}

@test "docs/HISTORY.md content is identical to the root HISTORY.md content" {
  diff -q "${DOCS_DIR}/HISTORY.md" "${REPO_ROOT}/HISTORY.md"
}

@test "the symlink targets do not point outside the repository (relative, single parent-dir hop)" {
  for link in index.md CHANGELOG.md HISTORY.md; do
    target="$(readlink "${DOCS_DIR}/${link}")"
    [[ "${target}" == ../* ]]
    [[ "${target}" != *"/../"* ]]
  done
}