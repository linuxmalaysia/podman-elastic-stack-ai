#!/usr/bin/env bats
#
# Regression tests for documentation content in UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md
# Guarantees line 1 frontmatter, Jekyll {% raw %}/{% endraw %} wrapping, OKF v0.2 metadata,
# section structures, and proper wiring into mkdocs.yml, llms.txt, sitemap.txt, and sitemap.xml.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
PLAYBOOK_DOC="${REPO_ROOT}/docs/UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md"
MKDOCS_YML="${REPO_ROOT}/mkdocs.yml"
LLMS_TXT="${REPO_ROOT}/llms.txt"
SITEMAP_TXT="${REPO_ROOT}/sitemap.txt"
SITEMAP_XML="${REPO_ROOT}/sitemap.xml"

@test "docs/UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md exists and is readable" {
  [ -f "${PLAYBOOK_DOC}" ]
  [ -r "${PLAYBOOK_DOC}" ]
}

@test "docs/UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md opens on line 1 with a YAML frontmatter marker" {
  first_line="$(head -n 1 "${PLAYBOOK_DOC}")"
  [ "${first_line}" = '---' ]
}

@test "docs/UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md contains valid OKF v0.2 metadata" {
  frontmatter="$(awk 'BEGIN {show=0; count=0} /^---$/ {count++; if(count==1) {show=1; next} if(count==2) {show=0; exit}} show {print}' "${PLAYBOOK_DOC}")"

  echo "${frontmatter}" | grep -Eq '^okf_version: ?"0\.2"?'
  echo "${frontmatter}" | grep -Eq '^type: ?"operations"?'
  echo "${frontmatter}" | grep -q 'title: "Universal Operational Replication & Prompt Playbook: Elastic Stack SOC Infrastructure Upgrade & Automation Fabric"'
  echo "${frontmatter}" | grep -q 'author: "Antigravity Cognitive Digital Twin & Lead SOC Architect"'
  echo "${frontmatter}" | grep -q 'date: "2026-09-05"'
  echo "${frontmatter}" | grep -q 'classification: "Universal Engineering Standard / Operational Playbook"'
  echo "${frontmatter}" | grep -q '^topics:'
}

@test "docs/UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md is properly wrapped in Jekyll {% raw %}/{% endraw %} tags" {
  marker2_line="$(grep -n '^---$' "${PLAYBOOK_DOC}" | sed -n '2p' | cut -d: -f1)"
  raw_line="$(grep -nF '{% raw %}' "${PLAYBOOK_DOC}" | head -1 | cut -d: -f1)"
  endraw_line="$(grep -nF '{% endraw %}' "${PLAYBOOK_DOC}" | head -1 | cut -d: -f1)"

  raw_count="$(grep -oF '{% raw %}' "${PLAYBOOK_DOC}" | wc -l)"
  endraw_count="$(grep -oF '{% endraw %}' "${PLAYBOOK_DOC}" | wc -l)"
  [ "${raw_count}" -eq 1 ]
  [ "${endraw_count}" -eq 1 ]

  [ -n "${marker2_line}" ]
  [ -n "${raw_line}" ]
  [ -n "${endraw_line}" ]
  [ "${raw_line}" -eq "$((marker2_line + 1))" ]
  [ "${endraw_line}" -gt "${raw_line}" ]
  [ "$(tail -n 1 "${PLAYBOOK_DOC}")" = '{% endraw %}' ]
}

@test "docs/UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md documents all top-level sections in order" {
  headers=(
    '# Universal Operational Replication & Prompt Playbook'
    '## 1. Executive Blueprint & Purpose'
    '## 2. Reusable AI Master Prompts'
    '## 3. Operational Skills Playbooks & Runbook Specifications'
    '## 4. Complete Declarative Ansible Playbook Suite'
    '## 5. Engineering Invariants & Failure Modes Solved'
    '## 6. Verification Queries & Telemetry Validation Suite'
    '## 7. Colophon & Attribution'
  )
  local prev_line=0
  for header in "${headers[@]}"; do
    line="$(grep -n -F "${header}" "${PLAYBOOK_DOC}" | head -1 | cut -d: -f1)"
    [ -n "${line}" ]
    [ "${line}" -gt "${prev_line}" ]
    prev_line="${line}"
  done
}

@test "mkdocs.yml registers the Universal Operational Replication Playbook nav entry" {
  grep -qF 'UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md' "${MKDOCS_YML}"
}

@test "llms.txt registers the Universal Operational Replication Playbook entry" {
  grep -qF 'UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md' "${LLMS_TXT}"
}

@test "sitemap.txt includes the UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK URL" {
  grep -qF 'https://linuxmalaysia.github.io/podman-elastic-stack-ai/docs/UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK/' "${SITEMAP_TXT}"
}

@test "sitemap.xml includes a <url> entry for UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK" {
  grep -qF '<loc>https://linuxmalaysia.github.io/podman-elastic-stack-ai/docs/UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK/</loc>' "${SITEMAP_XML}"
}
