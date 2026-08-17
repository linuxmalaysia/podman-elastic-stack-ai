#!/usr/bin/env bats
#
# Regression tests for WSL2 AI Performance & Security Tuning Guide
# (docs/WSL2_AI_PERFORMANCE_TUNING.md) and Python tuning script (scripts/wsl2_ai_tuning.py).

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
DOC_FILE="${REPO_ROOT}/docs/WSL2_AI_PERFORMANCE_TUNING.md"
SCRIPT_FILE="${REPO_ROOT}/scripts/wsl2_ai_tuning.py"

@test "docs/WSL2_AI_PERFORMANCE_TUNING.md exists and is readable" {
  [ -f "${DOC_FILE}" ]
  [ -r "${DOC_FILE}" ]
}

@test "docs/WSL2_AI_PERFORMANCE_TUNING.md opens on line 1 with YAML frontmatter marker" {
  first_line="$(head -n 1 "${DOC_FILE}")"
  [ "${first_line}" = "---" ]
}

@test "docs/WSL2_AI_PERFORMANCE_TUNING.md contains valid OKF metadata" {
  frontmatter="$(awk 'BEGIN {show=0; count=0} /^---$/ {count++; if(count==1) {show=1; next} if(count==2) {show=0; exit}} show {print}' "${DOC_FILE}")"
  echo "${frontmatter}" | grep -Fxq 'okf_version: 0.1'
  echo "${frontmatter}" | grep -Fxq 'type: documentation'
  echo "${frontmatter}" | grep -Fxq 'resource: file:///docs/WSL2_AI_PERFORMANCE_TUNING.md'
  echo "${frontmatter}" | grep -q '^topics: \[.*\]$'
}

@test "scripts/wsl2_ai_tuning.py exists, is readable, and executable" {
  [ -f "${SCRIPT_FILE}" ]
  [ -r "${SCRIPT_FILE}" ]
  [ -x "${SCRIPT_FILE}" ]
}

@test "scripts/wsl2_ai_tuning.py passes Python syntax check" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  python3 -m py_compile "${SCRIPT_FILE}"
}

@test "scripts/wsl2_ai_tuning.py --check executes cleanly" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  run python3 "${SCRIPT_FILE}" --check
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"WSL2 AI PERFORMANCE & SECURITY TUNING UTILITY"* ]]
  [[ "${output}" == *"Calculated WSL2 Memory"* ]]
  [[ "${output}" == *"System Audit"* ]]
}

@test "mkdocs.yml registers WSL2_AI_PERFORMANCE_TUNING.md" {
  grep -qF 'WSL2_AI_PERFORMANCE_TUNING.md' "${REPO_ROOT}/mkdocs.yml"
}

@test "sitemap.txt includes the WSL2_AI_PERFORMANCE_TUNING URL" {
  grep -qF 'https://linuxmalaysia.github.io/podman-elastic-stack-ai/docs/WSL2_AI_PERFORMANCE_TUNING/' "${REPO_ROOT}/sitemap.txt"
}

@test "sitemap.xml includes a <url> entry for WSL2_AI_PERFORMANCE_TUNING" {
  grep -qF '<loc>https://linuxmalaysia.github.io/podman-elastic-stack-ai/docs/WSL2_AI_PERFORMANCE_TUNING/</loc>' "${REPO_ROOT}/sitemap.xml"
}

@test "llms.txt includes the WSL2_AI_PERFORMANCE_TUNING.md entry" {
  grep -qF 'WSL2_AI_PERFORMANCE_TUNING.md' "${REPO_ROOT}/llms.txt"
}
