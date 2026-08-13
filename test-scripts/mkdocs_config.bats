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
  grep -qF -- '- scripts/mkdocs_hooks.py' "${MKDOCS_YML}"
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
  [ "${count}" -eq 2 ]
  count="$(grep -cF 'accent: custom' "${MKDOCS_YML}")"
  [ "${count}" -eq 2 ]
}

@test "mkdocs.yml enables navigation.expand and content.code.copy features" {
  grep -qF 'navigation.expand' "${MKDOCS_YML}"
  grep -qF 'content.code.copy' "${MKDOCS_YML}"
}

@test "mkdocs.yml wires up the custom extra CSS and JS assets" {
  grep -qF 'extra_css:' "${MKDOCS_YML}"
  grep -qF -- '- stylesheets/extra.css' "${MKDOCS_YML}"
  grep -qF 'extra_javascript:' "${MKDOCS_YML}"
  grep -qF -- '- javascripts/extra.js' "${MKDOCS_YML}"
}

@test "the extra CSS and JS assets referenced in mkdocs.yml actually exist under docs/" {
  [ -f "${REPO_ROOT}/docs/stylesheets/extra.css" ]
  [ -f "${REPO_ROOT}/docs/javascripts/extra.js" ]
}

@test "mkdocs.yml enables admonition and pymdownx markdown extensions" {
  grep -qF -- '- admonition' "${MKDOCS_YML}"
  grep -qF -- '- pymdownx.details' "${MKDOCS_YML}"
  grep -qF -- '- pymdownx.superfences' "${MKDOCS_YML}"
}

@test "mkdocs.yml nav lists Home first and Changelog last, covering all documentation pages" {
  local first_nav_line last_nav_line
  first_nav_line="$(grep -n -F -- '- Home: index.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  last_nav_line="$(grep -n -F -- '- Changelog: CHANGELOG.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  [ -n "${first_nav_line}" ]
  [ -n "${last_nav_line}" ]
  [ "${last_nav_line}" -gt "${first_nav_line}" ]

  grep -qF -- '- Installation Guide: INSTALL.md' "${MKDOCS_YML}"
  grep -qF -- '- Playbook Structure & Telemetry: PLAYBOOKS.md' "${MKDOCS_YML}"
  grep -qF -- '- Local Development & Feedback Guide: LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md' "${MKDOCS_YML}"
  grep -qF -- '- Rootless Podman 5+ & Quadlet Guide: PODMAN_ROOTLESS.md' "${MKDOCS_YML}"
  grep -qF -- '- Modern Ansible & FQCN Guide: ANSIBLE_FQCN.md' "${MKDOCS_YML}"
  grep -qF -- '- Ansible Adoption Review: ANSIBLE_ADOPTION_REVIEW.md' "${MKDOCS_YML}"
  grep -qF -- '- Playbook and Documents Map: ANSIBLE_PLAYBOOK_MAP.md' "${MKDOCS_YML}"
  grep -qF -- '- Local Knowledge-First Discovery SOP: SOP_KNOWLEDGE_FIRST_DISCOVERY.md' "${MKDOCS_YML}"
  grep -qF -- '- Sovereign Gitea Deployment & Security Operations Guide: GITEA_GUIDE.md' "${MKDOCS_YML}"
  grep -qF -- '- Sovereign SemaphoreUI Deployment & Operations Guide: SEMAPHORE_GUIDE.md' "${MKDOCS_YML}"
  grep -qF -- '- WSL 3-Node Cluster Guide: WSL-3NODE-CLUSTER-GUIDE.md' "${MKDOCS_YML}"
  grep -qF -- '- Developer Matrix Telemetry: DOCS_MATRIX_TELEMETRY.md' "${MKDOCS_YML}"
  grep -qF -- '- Legal Notice & Disclaimer: legal-notice.md' "${MKDOCS_YML}"
  grep -qF -- '- Project History: HISTORY.md' "${MKDOCS_YML}"
}

@test "every markdown file referenced in the mkdocs.yml nav exists under docs/" {
  for doc in index.md INSTALL.md PLAYBOOKS.md LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md PODMAN_ROOTLESS.md ANSIBLE_FQCN.md ANSIBLE_ADOPTION_REVIEW.md ANSIBLE_PLAYBOOK_MAP.md SOP_KNOWLEDGE_FIRST_DISCOVERY.md GITEA_GUIDE.md SEMAPHORE_GUIDE.md WSL-3NODE-CLUSTER-GUIDE.md REFERENCE_TUNING.md DOCS_MATRIX_TELEMETRY.md legal-notice.md HISTORY.md CHANGELOG.md ELASTIC_9_UPGRADE_PLAN.md; do
    [ -f "${REPO_ROOT}/docs/${doc}" ]
  done
}

@test "mkdocs.yml contains the exact navigation entry for ELASTIC_9_UPGRADE_PLAN.md" {
  grep -qF -- '- Upgrade Plan to Elastic 9.x: ELASTIC_9_UPGRADE_PLAN.md' "${MKDOCS_YML}"
}

# Regression tests for the "Reference Tuning Resources" nav entry, added
# between the WSL 3-Node Cluster Guide and the Developer Matrix Telemetry
# entries, pointing at the new docs/REFERENCE_TUNING.md page.

@test "mkdocs.yml registers the Reference Tuning Resources nav entry pointing at REFERENCE_TUNING.md" {
  grep -qF -- '- Reference Tuning Resources: REFERENCE_TUNING.md' "${MKDOCS_YML}"
}

@test "mkdocs.yml lists Reference Tuning Resources between the WSL 3-Node Cluster Guide and Developer Matrix Telemetry entries" {
  local wsl_line reference_line telemetry_line
  wsl_line="$(grep -n -F -- '- WSL 3-Node Cluster Guide: WSL-3NODE-CLUSTER-GUIDE.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  reference_line="$(grep -n -F -- '- Reference Tuning Resources: REFERENCE_TUNING.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  telemetry_line="$(grep -n -F -- '- Developer Matrix Telemetry: DOCS_MATRIX_TELEMETRY.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"

  [ -n "${wsl_line}" ]
  [ -n "${reference_line}" ]
  [ -n "${telemetry_line}" ]
  [ "${wsl_line}" -lt "${reference_line}" ]
  [ "${reference_line}" -lt "${telemetry_line}" ]
}

@test "mkdocs.yml registers the Legal Notice & Disclaimer nav entry pointing at legal-notice.md" {
  grep -qF -- '- Legal Notice & Disclaimer: legal-notice.md' "${MKDOCS_YML}"
}

@test "mkdocs.yml lists Legal Notice & Disclaimer between Developer Matrix Telemetry and Project History" {
  local telemetry_line legal_line history_line
  telemetry_line="$(grep -n -F -- '- Developer Matrix Telemetry: DOCS_MATRIX_TELEMETRY.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  legal_line="$(grep -n -F -- '- Legal Notice & Disclaimer: legal-notice.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  history_line="$(grep -n -F -- '- Project History: HISTORY.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"

  [ -n "${telemetry_line}" ]
  [ -n "${legal_line}" ]
  [ -n "${history_line}" ]
  [ "${telemetry_line}" -lt "${legal_line}" ]
  [ "${legal_line}" -lt "${history_line}" ]
}

@test "mkdocs.yml defines the custom legal notice copyright footer with the expected link" {
  grep -qF 'copyright:' "${MKDOCS_YML}"
  grep -qF 'legal-notice/' "${MKDOCS_YML}"
}

@test "the REFERENCE_TUNING.md file referenced by the new mkdocs.yml nav entry actually exists and is readable" {
  [ -f "${REPO_ROOT}/docs/REFERENCE_TUNING.md" ]
  [ -r "${REPO_ROOT}/docs/REFERENCE_TUNING.md" ]
}

# Regression tests for the new mkdocs.yml `copyright:` footer, which
# surfaces the legal disclaimer text and a link to docs/legal-notice.md on
# every rendered page of the MkDocs Material site.

@test "mkdocs.yml's copyright footer contains the expected disclaimer phrasing and copyright line" {
  grep -qF 'All costs, designs, unit amounts, and scenarios detailed within this project are based entirely on assumptions.' "${MKDOCS_YML}"
  grep -qF 'Compiled strictly for training, educational, and planning proposal purposes.' "${MKDOCS_YML}"
  grep -qF 'Use at your own risk.' "${MKDOCS_YML}"
  grep -qF 'We are not going to be responsible.' "${MKDOCS_YML}"
  grep -qF 'We have done our best to protect anyone and organisation.' "${MKDOCS_YML}"
  grep -qF 'Copyright &copy; 2025 - 2026 Harisfazillah Jamel (LinuxMalaysia)' "${MKDOCS_YML}"
}

@test "mkdocs.yml's copyright footer links to the legal-notice page with the expected anchor text" {
  grep -qF '<a href="https://linuxmalaysia.github.io/podman-elastic-stack-ai/legal-notice/">Legal Notice, Privacy Policy, Critical Assumptions & Disclaimer of Liability</a>' "${MKDOCS_YML}"
}

@test "mkdocs.yml declares copyright as a single-quoted YAML scalar" {
  local copyright_line
  copyright_line="$(grep -n -E '^copyright: ' "${MKDOCS_YML}" | head -1)"
  [ -n "${copyright_line}" ]
  echo "${copyright_line}" | grep -qE ": '"
}

@test "mkdocs.yml's copyright line appears before the hooks: section" {
  local copyright_line hooks_line
  copyright_line="$(grep -n -E '^copyright: ' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  hooks_line="$(grep -n -F -- 'hooks:' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  [ -n "${copyright_line}" ]
  [ -n "${hooks_line}" ]
  [ "${copyright_line}" -lt "${hooks_line}" ]
}

@test "mkdocs.yml declares exactly one copyright entry (no duplicates)" {
  local count
  count="$(grep -cE '^copyright: ' "${MKDOCS_YML}")"
  [ "${count}" -eq 1 ]
}

@test "the legal-notice.md file referenced by the new mkdocs.yml nav entry and copyright footer actually exists and is readable" {
  [ -f "${REPO_ROOT}/docs/legal-notice.md" ]
  [ -r "${REPO_ROOT}/docs/legal-notice.md" ]
}

# Regression tests for the new "Upgrade Plan to Elastic 9.x" nav entry,
# added between the WSL 3-Node Cluster Guide and Reference Tuning Resources
# entries, pointing at the new docs/ELASTIC_9_UPGRADE_PLAN.md page.

@test "mkdocs.yml registers the Upgrade Plan to Elastic 9.x nav entry pointing at ELASTIC_9_UPGRADE_PLAN.md" {
  grep -qF -- '- Upgrade Plan to Elastic 9.x: ELASTIC_9_UPGRADE_PLAN.md' "${MKDOCS_YML}"
}

@test "mkdocs.yml lists Upgrade Plan to Elastic 9.x between the WSL 3-Node Cluster Guide and Reference Tuning Resources entries" {
  local wsl_line upgrade_line reference_line
  wsl_line="$(grep -n -F -- '- WSL 3-Node Cluster Guide: WSL-3NODE-CLUSTER-GUIDE.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  upgrade_line="$(grep -n -F -- '- Upgrade Plan to Elastic 9.x: ELASTIC_9_UPGRADE_PLAN.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  reference_line="$(grep -n -F -- '- Reference Tuning Resources: REFERENCE_TUNING.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"

  [ -n "${wsl_line}" ]
  [ -n "${upgrade_line}" ]
  [ -n "${reference_line}" ]
  [ "${wsl_line}" -lt "${upgrade_line}" ]
  [ "${upgrade_line}" -lt "${reference_line}" ]
}

@test "mkdocs.yml declares exactly one Upgrade Plan to Elastic 9.x nav entry (no duplicates)" {
  local count
  count="$(grep -cF -- '- Upgrade Plan to Elastic 9.x: ELASTIC_9_UPGRADE_PLAN.md' "${MKDOCS_YML}")"
  [ "${count}" -eq 1 ]
}

@test "the ELASTIC_9_UPGRADE_PLAN.md file referenced by the new mkdocs.yml nav entry actually exists and is readable" {
  [ -f "${REPO_ROOT}/docs/ELASTIC_9_UPGRADE_PLAN.md" ]
  [ -r "${REPO_ROOT}/docs/ELASTIC_9_UPGRADE_PLAN.md" ]
}