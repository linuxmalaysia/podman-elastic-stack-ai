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
