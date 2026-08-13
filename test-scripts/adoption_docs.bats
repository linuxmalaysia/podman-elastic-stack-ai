#!/usr/bin/env bats
#
# Regression tests for newly adopted documentation guides.
# Ensures proper OKF frontmatter structure, metadata elements,
# and Jekyll {% raw %}/{% endraw %} wrapping constraints are met.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

NEW_DOCS=(
  "docs/PODMAN_ROOTLESS.md"
  "docs/ANSIBLE_FQCN.md"
  "docs/ANSIBLE_ADOPTION_REVIEW.md"
  "docs/ANSIBLE_PLAYBOOK_MAP.md"
  "docs/SOP_KNOWLEDGE_FIRST_DISCOVERY.md"
  "docs/ELASTIC_9_UPGRADE_PLAN.md"
)

@test "all new adoption documentation files exist and are readable" {
  for doc in "${NEW_DOCS[@]}"; do
    [ -f "${REPO_ROOT}/${doc}" ]
    [ -r "${REPO_ROOT}/${doc}" ]
  done
}

@test "all new adoption documentation files open on line 1 with a YAML frontmatter marker" {
  for doc in "${NEW_DOCS[@]}"; do
    first_line="$(head -n 1 "${REPO_ROOT}/${doc}")"
    [ "${first_line}" = '---' ]
  done
}

@test "all new adoption documentation files contain valid OKF metadata and topics" {
  for doc in "${NEW_DOCS[@]}"; do
    # Extract frontmatter between the first two --- markers
    frontmatter="$(awk 'BEGIN {show=0; count=0} /^---$/ {count++; if(count==1) {show=1; next} if(count==2) {show=0; exit}} show {print}' "${REPO_ROOT}/${doc}")"

    # Validate okf_version, type, resource, and topics only within that block, anchored to full field values
    echo "${frontmatter}" | grep -Fxq 'okf_version: 0.1'
    echo "${frontmatter}" | grep -Fxq 'type: documentation'
    echo "${frontmatter}" | grep -Fxq "resource: file:///${doc}"
    echo "${frontmatter}" | grep -q '^topics: \[[a-z0-9, -]*\]$'
  done
}

@test "all new adoption documentation files are properly wrapped in Jekyll {% raw %}/{% endraw %} tags" {
  for doc in "${NEW_DOCS[@]}"; do
    # Find line numbers of second --- marker and Jekyll tags
    marker2_line="$(grep -n '^---$' "${REPO_ROOT}/${doc}" | sed -n '2p' | cut -d: -f1)"
    raw_line="$(grep -nF '{% raw %}' "${REPO_ROOT}/${doc}" | head -1 | cut -d: -f1)"
    endraw_line="$(grep -nF '{% endraw %}' "${REPO_ROOT}/${doc}" | head -1 | cut -d: -f1)"

    # Assert exactly one occurrence of {% raw %} and {% endraw %} using occurrence-counting logic
    raw_count="$(grep -oF '{% raw %}' "${REPO_ROOT}/${doc}" | wc -l)"
    endraw_count="$(grep -oF '{% endraw %}' "${REPO_ROOT}/${doc}" | wc -l)"
    [ "${raw_count}" -eq 1 ]
    [ "${endraw_count}" -eq 1 ]

    # Assert {% raw %} occurring after the closing frontmatter marker and before {% endraw %}
    [ -n "${marker2_line}" ]
    [ -n "${raw_line}" ]
    [ -n "${endraw_line}" ]
    [ "${raw_line}" -gt "${marker2_line}" ]
    [ "${endraw_line}" -gt "${raw_line}" ]
  done
}

# Regression tests for the new docs/ELASTIC_9_UPGRADE_PLAN.md upgrade guide,
# ensuring its frontmatter metadata and structural content sections are
# present and correctly formed.

ELASTIC_9_UPGRADE_PLAN="${REPO_ROOT}/docs/ELASTIC_9_UPGRADE_PLAN.md"

@test "ELASTIC_9_UPGRADE_PLAN.md declares the expected title, description, and topics in its frontmatter" {
  frontmatter="$(awk 'BEGIN {show=0; count=0} /^---$/ {count++; if(count==1) {show=1; next} if(count==2) {show=0; exit}} show {print}' "${ELASTIC_9_UPGRADE_PLAN}")"

  echo "${frontmatter}" | grep -Fxq 'title: "ELASTIC_9_UPGRADE_PLAN.md"'
  echo "${frontmatter}" | grep -Fxq 'description: "Comprehensive Guide and 2-Week Plan for Upgrading the Podman-based Elastic Stack to Version 9.5.x or Latest."'
  echo "${frontmatter}" | grep -Fxq 'topics: [elastic, upgrade, planning, migration, podman, ansible]'
}

@test "ELASTIC_9_UPGRADE_PLAN.md's resource frontmatter field points at its own file path" {
  grep -qF 'resource: file:///docs/ELASTIC_9_UPGRADE_PLAN.md' "${ELASTIC_9_UPGRADE_PLAN}"
}

@test "ELASTIC_9_UPGRADE_PLAN.md declares a timestamp field in its frontmatter" {
  grep -qE '^timestamp: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "${ELASTIC_9_UPGRADE_PLAN}"
}

@test "ELASTIC_9_UPGRADE_PLAN.md contains the top-level architectural and scheduling section headers" {
  grep -qF '# 🚀 Elastic Stack 9.5.x (or Latest) Upgrade Plan' "${ELASTIC_9_UPGRADE_PLAN}"
  grep -qF '## 🏛️ 1. Architectural Impact & Sovereign Strategy' "${ELASTIC_9_UPGRADE_PLAN}"
  grep -qF '## 📅 2. The 2-Week Master Upgrade Schedule' "${ELASTIC_9_UPGRADE_PLAN}"
  grep -qF '## 🛠️ 3. Execution Phase Deep Dive' "${ELASTIC_9_UPGRADE_PLAN}"
  grep -qF '## 📊 4. Upgrade Risk & Mitigation Matrix' "${ELASTIC_9_UPGRADE_PLAN}"
}

@test "ELASTIC_9_UPGRADE_PLAN.md documents the mandatory upgrade ordering constraint for Fleet Server and Elastic Agents" {
  grep -qF 'Fleet Server must be upgraded before any of its connected downstream Elastic Agents.' "${ELASTIC_9_UPGRADE_PLAN}"
  grep -qF 'Elasticsearch ➔ Kibana ➔ Fleet Server ➔ Elastic Agents.' "${ELASTIC_9_UPGRADE_PLAN}"
}

@test "ELASTIC_9_UPGRADE_PLAN.md's risk matrix table lists all five documented upgrade risks" {
  grep -qF '| **Index Mapping Conflicts** | High |' "${ELASTIC_9_UPGRADE_PLAN}"
  grep -qF '| **SubUID/SubGID Ownership Reset** | Medium |' "${ELASTIC_9_UPGRADE_PLAN}"
  grep -qF '| **Fleet / Agent Version Mismatch** | High |' "${ELASTIC_9_UPGRADE_PLAN}"
  grep -qF '| **Deprecated Ingest Processors** | Medium |' "${ELASTIC_9_UPGRADE_PLAN}"
  grep -qF '| **Airgap Image Resolution Failures** | Medium |' "${ELASTIC_9_UPGRADE_PLAN}"
}

@test "ELASTIC_9_UPGRADE_PLAN.md's Week 1 and Week 2 execution sections cover all nine numbered upgrade steps in order" {
  local step_lines
  step_lines="$(grep -nE '^#### [0-9]+\. ' "${ELASTIC_9_UPGRADE_PLAN}" | cut -d: -f1)"
  local count
  count="$(echo "${step_lines}" | wc -l)"
  [ "${count}" -eq 9 ]

  # Verify the numbered steps appear in strictly increasing line order (1..9).
  local prev=0
  for line in ${step_lines}; do
    [ "${line}" -gt "${prev}" ]
    prev="${line}"
  done
}

@test "ELASTIC_9_UPGRADE_PLAN.md has no trailing newline, matching the source PR diff" {
  run python3 -c "
data = open('${ELASTIC_9_UPGRADE_PLAN}', 'rb').read()
print('newline' if data.endswith(b'\n') else 'no-newline')
"
  [ "${status}" -eq 0 ]
  [ "${output}" = "no-newline" ]
}

@test "ELASTIC_9_UPGRADE_PLAN.md's {% endraw %} tag is the final line of the file" {
  local last_line
  last_line="$(tail -n 1 "${ELASTIC_9_UPGRADE_PLAN}")"
  [ "${last_line}" = "{% endraw %}" ]
}
