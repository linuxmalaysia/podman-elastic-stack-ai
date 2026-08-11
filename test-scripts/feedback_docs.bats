#!/usr/bin/env bats
#
# Regression tests for documentation content in LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md.
# These ensure that the local development setup, multi-OS testing matrix,
# and bidirectional feedback loop are correctly and persistently documented.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
GUIDE="${REPO_ROOT}/docs/LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md"

@test "LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md exists and is readable" {
  [ -f "${GUIDE}" ]
  [ -r "${GUIDE}" ]
}

@test "GUIDE documents Windows WSL2 and Ubuntu 26.04 LTS" {
  grep -qF 'Windows WSL2 (Ubuntu 26.04 LTS)' "${GUIDE}"
}

@test "GUIDE documents Podman 5+ requirement" {
  grep -qF 'Podman 5+' "${GUIDE}"
}

@test "GUIDE documents Developer vs User Mode separation protocol" {
  grep -qF 'Mode Separation Protocol (Developer vs User Mode)' "${GUIDE}"
  grep -qF 'EXECUTION_MODE=dev' "${GUIDE}"
  grep -qF 'EXECUTION_MODE=user' "${GUIDE}"
}

@test "GUIDE documents Ansible matrix test playbook" {
  grep -qF 'playbooks/matrix_test.yml' "${GUIDE}"
}

@test "GUIDE documents feedback collector tasks" {
  grep -qF 'playbooks/roles/feedback_collector/tasks/main.yml' "${GUIDE}"
}

@test "GUIDE documents feedback bridge script" {
  grep -qF 'scripts/jules_gh_feedback.sh' "${GUIDE}"
}

@test "GUIDE contains complete copy-paste ready code files with zero omissions" {
  grep -qF '[defaults]' "${GUIDE}"
  grep -qF 'feedback_collector' "${GUIDE}"
  grep -qF 'jules_test_ubuntu_26_04' "${GUIDE}"
  grep -qF 'jules_gh_feedback.sh' "${GUIDE}"
}

@test "GUIDE is wrapped in Jekyll {% raw %}/{% endraw %} tags" {
  # Regression guard: the guide contains extensive Ansible/Jinja2
  # double-curly-brace syntax (e.g. "{{ playbook_dir }}") that Jekyll's
  # Liquid engine would otherwise attempt to parse and fail to build on
  # GitHub Pages. The entire document must be wrapped in raw/endraw tags.
  first_line="$(head -n 1 "${GUIDE}")"
  last_line="$(tail -n 1 "${GUIDE}")"
  [ "${first_line}" = '{% raw %}' ] || [ "${first_line}" = '<!-- markdownlint-disable MD041 -->{% raw %}' ]
  [ "${last_line}" = '{% endraw %}' ]
}

@test "GUIDE has exactly one raw/endraw tag pair (no duplicates or stray tags)" {
  raw_count="$(grep -cF -- '{% raw %}' "${GUIDE}")"
  endraw_count="$(grep -cF -- '{% endraw %}' "${GUIDE}")"
  [ "${raw_count}" -eq 1 ]
  [ "${endraw_count}" -eq 1 ]
}

@test "GUIDE's title immediately follows the opening {% raw %} tag" {
  second_line="$(sed -n '2p' "${GUIDE}")"
  [ "${second_line}" = '# Local Hybrid Execution & Bidirectional Feedback Pipeline Guide' ]
}

@test "GUIDE's current first line is the markdownlint-disable-fused {% raw %} form" {
  # Regression guard/documentation: pins down which of the two forms
  # accepted by "GUIDE is wrapped in Jekyll {% raw %}/{% endraw %} tags" is
  # actually present today, so an unintentional switch between the two
  # forms is still caught by a targeted assertion.
  first_line="$(head -n 1 "${GUIDE}")"
  [ "${first_line}" = '<!-- markdownlint-disable MD041 -->{% raw %}' ]
}

@test "GUIDE's fused markdownlint-disable/raw first line ends with the exact '{% raw %}' tag (no typos or extra whitespace)" {
  first_line="$(head -n 1 "${GUIDE}")"
  case "${first_line}" in
    *'{% raw %}') ;;
    *) return 1 ;;
  esac
}

@test "GUIDE's nested Liquid-style docker stats format string is enclosed within the raw block" {
  # This line contains deeply nested "{{ '{{' }}" escape-style sequences
  # which are especially prone to breaking a naive Liquid parser; confirm
  # it is located between the opening and closing raw tags.
  raw_line="$(grep -nF -- '{% raw %}' "${GUIDE}" | head -1 | cut -d: -f1)"
  endraw_line="$(grep -nF -- '{% endraw %}' "${GUIDE}" | head -1 | cut -d: -f1)"
  nested_line="$(grep -nF -- "CPUPerc" "${GUIDE}" | head -1 | cut -d: -f1)"
  [ -n "${nested_line}" ]
  [ "${nested_line}" -gt "${raw_line}" ]
  [ "${nested_line}" -lt "${endraw_line}" ]
}

@test "GUIDE ends with the exit 0 fenced code block immediately before the closing {% endraw %} tag" {
  # Regression guard: ensures {% endraw %} was appended after the existing
  # final content rather than replacing or truncating it.
  mapfile -t last_lines < <(tail -n 3 "${GUIDE}")
  [ "${last_lines[0]}" = 'exit 0' ]
  [ "${last_lines[1]}" = '```' ]
  [ "${last_lines[2]}" = '{% endraw %}' ]
}
