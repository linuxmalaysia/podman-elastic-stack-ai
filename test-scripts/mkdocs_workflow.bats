#!/usr/bin/env bats
#
# Regression tests for the GitHub Pages deployment workflow, which was
# converted from a Jekyll-based build (.github/workflows/jekyll-gh-pages.yml)
# to a MkDocs-based build (.github/workflows/mkdocs-gh-pages.yml).

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
WORKFLOW="${REPO_ROOT}/.github/workflows/mkdocs-gh-pages.yml"
OLD_WORKFLOW="${REPO_ROOT}/.github/workflows/jekyll-gh-pages.yml"

@test "mkdocs-gh-pages.yml exists and is readable" {
  [ -f "${WORKFLOW}" ]
  [ -r "${WORKFLOW}" ]
}

@test "the old jekyll-gh-pages.yml workflow no longer exists (renamed, not duplicated)" {
  [ ! -f "${OLD_WORKFLOW}" ]
}

@test "workflow is named for MkDocs, not Jekyll" {
  grep -qF 'name: Deploy MkDocs with GitHub Pages' "${WORKFLOW}"
  run grep -qi 'jekyll' "${WORKFLOW}"
  [ "${status}" -ne 0 ]
}

@test "workflow triggers on push to main and workflow_dispatch" {
  grep -qF 'branches: ["main"]' "${WORKFLOW}"
  grep -qF 'workflow_dispatch:' "${WORKFLOW}"
}

@test "workflow grants write permission on contents (required for gh-deploy / edit links)" {
  grep -qE '^\s*contents:\s*write' "${WORKFLOW}"
}

@test "workflow still grants pages write and id-token write permissions" {
  grep -qE '^\s*pages:\s*write' "${WORKFLOW}"
  grep -qE '^\s*id-token:\s*write' "${WORKFLOW}"
}

@test "checkout step fetches full history (fetch-depth: 0)" {
  grep -qF 'uses: actions/checkout@v4' "${WORKFLOW}"
  grep -qF 'fetch-depth: 0' "${WORKFLOW}"
}

@test "workflow sets up Python 3.x" {
  grep -qF 'uses: actions/setup-python@v5' "${WORKFLOW}"
  grep -qF 'python-version: "3.x"' "${WORKFLOW}"
}

@test "workflow installs mkdocs-material via pip" {
  grep -qF 'pip install mkdocs-material' "${WORKFLOW}"
}

@test "workflow builds the site with mkdocs, targeting ./_site" {
  grep -qF 'mkdocs build --site-dir ./_site' "${WORKFLOW}"
}

@test "workflow no longer uses the jekyll-build-pages action" {
  run grep -qF 'jekyll-build-pages' "${WORKFLOW}"
  [ "${status}" -ne 0 ]
}

@test "workflow still configures Pages and uploads/deploys the built artifact" {
  grep -qF 'uses: actions/configure-pages@v5' "${WORKFLOW}"
  grep -qF 'uses: actions/upload-pages-artifact@v3' "${WORKFLOW}"
  grep -qF 'uses: actions/deploy-pages@v5' "${WORKFLOW}"
}

@test "workflow build steps occur in the expected order: checkout, python setup, deps, pages config, mkdocs build, upload" {
  local checkout_line python_line deps_line pages_line build_line upload_line
  checkout_line="$(grep -n -F 'uses: actions/checkout@v4' "${WORKFLOW}" | head -1 | cut -d: -f1)"
  python_line="$(grep -n -F 'uses: actions/setup-python@v5' "${WORKFLOW}" | head -1 | cut -d: -f1)"
  deps_line="$(grep -n -F 'pip install mkdocs-material' "${WORKFLOW}" | head -1 | cut -d: -f1)"
  pages_line="$(grep -n -F 'uses: actions/configure-pages@v5' "${WORKFLOW}" | head -1 | cut -d: -f1)"
  build_line="$(grep -n -F 'mkdocs build --site-dir ./_site' "${WORKFLOW}" | head -1 | cut -d: -f1)"
  upload_line="$(grep -n -F 'uses: actions/upload-pages-artifact@v3' "${WORKFLOW}" | head -1 | cut -d: -f1)"

  [ "${python_line}" -gt "${checkout_line}" ]
  [ "${deps_line}" -gt "${python_line}" ]
  [ "${pages_line}" -gt "${deps_line}" ]
  [ "${build_line}" -gt "${pages_line}" ]
  [ "${upload_line}" -gt "${build_line}" ]
}

@test "deploy job still depends on the build job" {
  grep -qF 'needs: build' "${WORKFLOW}"
}

@test "docs-ci.yml exists and configures gitleaks and ansible-lint jobs" {
  local docs_ci="${REPO_ROOT}/.github/workflows/docs-ci.yml"
  [ -f "${docs_ci}" ]
  grep -qF 'gitleaks/gitleaks-action' "${docs_ci}"
  grep -qF 'ansible/ansible-lint-action' "${docs_ci}"
}