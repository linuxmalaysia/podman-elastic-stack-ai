#!/usr/bin/env bats
#
# Regression tests for the new top-level mkdocs.yml configuration, which
# defines the MkDocs Material site used to replace the previous Jekyll-based
# GitHub Pages build.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
MKDOCS_YML="${REPO_ROOT}/mkdocs.yml"

@test "mkdocs.yml exists and is readable" {
  [ -f "${MKDOCS_YML}" ]
  [ -r "${MKDOCS_YML}" ]
}

@test "mkdocs.yml declares site metadata" {
  grep -qF 'site_name: Podman Elastic Stack AI' "${MKDOCS_YML}"
  grep -qF 'site_author: Harisfazillah Jamel (LinuxMalaysia)' "${MKDOCS_YML}"
  grep -qF 'repo_url: https://github.com/linuxmalaysia/podman-elastic-stack-ai' "${MKDOCS_YML}"
  grep -qF 'site_url: https://linuxmalaysia.github.io/podman-elastic-stack-ai/' "${MKDOCS_YML}"
}

@test "mkdocs.yml sets edit_uri to the docs/ directory on main" {
  grep -qF 'edit_uri: blob/main/docs/' "${MKDOCS_YML}"
}

@test "mkdocs.yml registers the mkdocs_hooks.py link-rewriting hook" {
  grep -qF 'hooks:' "${MKDOCS_YML}"
  grep -qF '- scripts/mkdocs_hooks.py' "${MKDOCS_YML}"
}

@test "the hook file referenced in mkdocs.yml actually exists" {
  [ -f "${REPO_ROOT}/scripts/mkdocs_hooks.py" ]
}

@test "mkdocs.yml excludes docs by default except the .agents directory" {
  grep -qF 'exclude_docs:' "${MKDOCS_YML}"
  grep -qF '!.agents' "${MKDOCS_YML}"
}

@test "mkdocs.yml configures link validation to warn on absolute links and ignore unrecognized links" {
  grep -qF 'absolute_links: warn' "${MKDOCS_YML}"
  grep -qF 'unrecognized_links: ignore' "${MKDOCS_YML}"
}

@test "mkdocs.yml uses the material theme with Inter/Roboto Mono fonts" {
  grep -qF 'name: material' "${MKDOCS_YML}"
  grep -qF 'text: Inter' "${MKDOCS_YML}"
  grep -qF 'code: Roboto Mono' "${MKDOCS_YML}"
}

@test "mkdocs.yml defines auto, light, and dark palette toggles" {
  grep -qF 'media: "(prefers-color-scheme)"' "${MKDOCS_YML}"
  grep -qF 'media: "(prefers-color-scheme: light)"' "${MKDOCS_YML}"
  grep -qF 'media: "(prefers-color-scheme: dark)"' "${MKDOCS_YML}"
  grep -qF 'scheme: default' "${MKDOCS_YML}"
  grep -qF 'scheme: slate' "${MKDOCS_YML}"
}

@test "mkdocs.yml uses the custom primary/accent palette (not a stock Material color) for both light and dark" {
  local count
  count="$(grep -cF 'primary: custom' "${MKDOCS_YML}")"
  [ "${count}" -eq 1 ]
  count="$(grep -cF 'accent: custom' "${MKDOCS_YML}")"
  [ "${count}" -eq 1 ]
}

@test "mkdocs.yml enables navigation.expand and content.code.copy features" {
  grep -qF 'navigation.expand' "${MKDOCS_YML}"
  grep -qF 'content.code.copy' "${MKDOCS_YML}"
}

@test "mkdocs.yml wires up the custom extra CSS and JS assets" {
  grep -qF 'extra_css:' "${MKDOCS_YML}"
  grep -qF '- stylesheets/extra.css' "${MKDOCS_YML}"
  grep -qF 'extra_javascript:' "${MKDOCS_YML}"
  grep -qF '- javascripts/extra.js' "${MKDOCS_YML}"
}

@test "the extra CSS and JS assets referenced in mkdocs.yml actually exist under docs/" {
  [ -f "${REPO_ROOT}/docs/stylesheets/extra.css" ]
  [ -f "${REPO_ROOT}/docs/javascripts/extra.js" ]
}

@test "mkdocs.yml enables admonition and pymdownx markdown extensions" {
  grep -qF '- admonition' "${MKDOCS_YML}"
  grep -qF '- pymdownx.details' "${MKDOCS_YML}"
  grep -qF '- pymdownx.superfences' "${MKDOCS_YML}"
}

@test "mkdocs.yml nav lists Home first and Changelog last, covering all documentation pages" {
  local first_nav_line last_nav_line
  first_nav_line="$(grep -n -F '- Home: index.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  last_nav_line="$(grep -n -F '- Changelog: CHANGELOG.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  [ -n "${first_nav_line}" ]
  [ -n "${last_nav_line}" ]
  [ "${last_nav_line}" -gt "${first_nav_line}" ]

  grep -qF '- Installation Guide: INSTALL.md' "${MKDOCS_YML}"
  grep -qF '- Playbook Structure & Telemetry: PLAYBOOKS.md' "${MKDOCS_YML}"
  grep -qF '- Local Development & Feedback Guide: LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md' "${MKDOCS_YML}"
  grep -qF '- Sovereign Gitea Deployment & Security Operations Guide: GITEA_GUIDE.md' "${MKDOCS_YML}"
  grep -qF '- WSL 3-Node Cluster Guide: WSL-3NODE-CLUSTER-GUIDE.md' "${MKDOCS_YML}"
  grep -qF '- Developer Matrix Telemetry: DOCS_MATRIX_TELEMETRY.md' "${MKDOCS_YML}"
  grep -qF '- Project History: HISTORY.md' "${MKDOCS_YML}"
}

@test "every markdown file referenced in the mkdocs.yml nav exists under docs/" {
  for doc in index.md INSTALL.md PLAYBOOKS.md LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md GITEA_GUIDE.md WSL-3NODE-CLUSTER-GUIDE.md DOCS_MATRIX_TELEMETRY.md HISTORY.md CHANGELOG.md; do
    [ -f "${REPO_ROOT}/docs/${doc}" ]
  done
}