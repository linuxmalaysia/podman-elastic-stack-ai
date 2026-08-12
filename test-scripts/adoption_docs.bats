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
    grep -q 'okf_version: 0.1' "${REPO_ROOT}/${doc}"
    grep -q 'type: documentation' "${REPO_ROOT}/${doc}"
    grep -q 'resource: file:///' "${REPO_ROOT}/${doc}"
    # Check that topics is defined
    grep -q 'topics: \[' "${REPO_ROOT}/${doc}"
  done
}

@test "all new adoption documentation files are properly wrapped in Jekyll {% raw %}/{% endraw %} tags" {
  for doc in "${NEW_DOCS[@]}"; do
    # Verify presence of raw and endraw tags
    grep -qF '{% raw %}' "${REPO_ROOT}/${doc}"
    grep -qF '{% endraw %}' "${REPO_ROOT}/${doc}"

    # Confirm there is exactly one raw and one endraw tag
    raw_count="$(grep -cF '{% raw %}' "${REPO_ROOT}/${doc}")"
    endraw_count="$(grep -cF '{% endraw %}' "${REPO_ROOT}/${doc}")"
    [ "${raw_count}" -eq 1 ]
    [ "${endraw_count}" -eq 1 ]
  done
}
