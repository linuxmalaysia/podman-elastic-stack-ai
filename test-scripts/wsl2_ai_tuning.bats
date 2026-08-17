#!/usr/bin/env bats
#
# Regression tests for WSL2 AI Performance & Security Tuning Guide
# (docs/WSL2_AI_PERFORMANCE_TUNING.md) and Python tuning script (scripts/wsl2_ai_tuning.py).

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
DOC_FILE="${REPO_ROOT}/docs/WSL2_AI_PERFORMANCE_TUNING.md"
SCRIPT_FILE="${REPO_ROOT}/scripts/wsl2_ai_tuning.py"
REFERENCE_TUNING_DOC="${REPO_ROOT}/docs/REFERENCE_TUNING.md"
LLMS_TXT="${REPO_ROOT}/llms.txt"
MKDOCS_YML="${REPO_ROOT}/mkdocs.yml"
SITEMAP_TXT="${REPO_ROOT}/sitemap.txt"
SITEMAP_XML="${REPO_ROOT}/sitemap.xml"
BASE_URL="https://linuxmalaysia.github.io/podman-elastic-stack-ai"

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

# ------------------------------------------------------------------------
# docs/WSL2_AI_PERFORMANCE_TUNING.md: additional frontmatter fields
# ------------------------------------------------------------------------

@test "docs/WSL2_AI_PERFORMANCE_TUNING.md frontmatter declares title, description, and topics fields" {
  frontmatter="$(awk 'BEGIN {show=0; count=0} /^---$/ {count++; if(count==1) {show=1; next} if(count==2) {show=0; exit}} show {print}' "${DOC_FILE}")"
  echo "${frontmatter}" | grep -Fxq 'title: "WSL2 AI Performance & Security Tuning Guide"'
  echo "${frontmatter}" | grep -Fq 'description: "Comprehensive WSL2 performance tuning, networking, and security architecture guide'
  echo "${frontmatter}" | grep -Fxq 'topics: [wsl2, podman, claude-code, gemini-cli, ai, tuning, security, almalinux, ubuntu]'
}

@test "docs/WSL2_AI_PERFORMANCE_TUNING.md frontmatter declares an ISO-8601 timestamp field" {
  frontmatter="$(awk 'BEGIN {show=0; count=0} /^---$/ {count++; if(count==1) {show=1; next} if(count==2) {show=0; exit}} show {print}' "${DOC_FILE}")"
  echo "${frontmatter}" | grep -qE '^timestamp: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
}

@test "docs/WSL2_AI_PERFORMANCE_TUNING.md's title heading immediately follows the closing frontmatter marker" {
  marker2_line="$(grep -n '^---$' "${DOC_FILE}" | sed -n '2p' | cut -d: -f1)"
  [ -n "${marker2_line}" ]
  next_line="$(sed -n "$((marker2_line + 1))p" "${DOC_FILE}")"
  [ "${next_line}" = '# 🚀 WSL2 AI Performance & Security Tuning Guide' ]
}

# ------------------------------------------------------------------------
# docs/WSL2_AI_PERFORMANCE_TUNING.md: section structure and content
# ------------------------------------------------------------------------

@test "docs/WSL2_AI_PERFORMANCE_TUNING.md documents all eleven top-level sections in order" {
  headers=(
    '## 1. Executive Summary & Core Architectural Principles'
    '## 2. Target Linux Distributions Comparison'
    '## 3. Native Linux Filesystem vs. 9P Bridge Performance (~9x Win)'
    '## 4. Windows 11 Host Hardware Calculations & Global `.wslconfig`'
    '## 5. Per-Distribution Configuration (`/etc/wsl.conf`)'
    '## 6. Kernel and System Limits Optimization'
    '## 7. GPU Acceleration & CUDA Passthrough'
    '## 8. Security & Environment Variable Management'
    '## 9. Disk Space Management & VHD Reclamation'
    '## 10. AI Toolchain & Sandboxing Installation'
    '## 11. Automated Python `uv` Script (`scripts/wsl2_ai_tuning.py`)'
  )
  local prev_line=0
  for header in "${headers[@]}"; do
    line="$(grep -n -F -- "${header}" "${DOC_FILE}" | head -1 | cut -d: -f1)"
    [ -n "${line}" ]
    [ "${line}" -gt "${prev_line}" ]
    prev_line="${line}"
  done
}

@test "docs/WSL2_AI_PERFORMANCE_TUNING.md documents both target distributions" {
  grep -qF 'AlmaLinux 10' "${DOC_FILE}"
  grep -qF 'Ubuntu 26.04 LTS' "${DOC_FILE}"
}

@test "docs/WSL2_AI_PERFORMANCE_TUNING.md documents the RAM allocation matrix matching wsl_tuning.yml's tiers" {
  grep -qF '**10 GB** (`memory=10GB`)' "${DOC_FILE}"
  grep -qF '**22 GB** (`memory=22GB`)' "${DOC_FILE}"
  grep -qF '**48 GB** (`memory=48GB`)' "${DOC_FILE}"
  grep -qF '**96 GB** (`memory=96GB`)' "${DOC_FILE}"
}

@test "docs/WSL2_AI_PERFORMANCE_TUNING.md documents the kernel tuning values used by the playbook and script" {
  grep -qF '`fs.inotify.max_user_watches`' "${DOC_FILE}"
  grep -qF '524288' "${DOC_FILE}"
  grep -qF '`vm.max_map_count`' "${DOC_FILE}"
  grep -qF '262144' "${DOC_FILE}"
  grep -qF '65535' "${DOC_FILE}"
}

@test "docs/WSL2_AI_PERFORMANCE_TUNING.md documents both networking modes" {
  grep -qF 'networkingMode=mirrored' "${DOC_FILE}"
  grep -qF 'networkingMode=nat' "${DOC_FILE}"
}

@test "docs/WSL2_AI_PERFORMANCE_TUNING.md documents the three protected API key environment variables" {
  grep -qF 'ANTHROPIC_API_KEY' "${DOC_FILE}"
  grep -qF 'GEMINI_API_KEY' "${DOC_FILE}"
  grep -qF 'OPENAI_API_KEY' "${DOC_FILE}"
}

@test "docs/WSL2_AI_PERFORMANCE_TUNING.md's section 11 documents both --check and --apply invocations of the script" {
  grep -qF 'uv run scripts/wsl2_ai_tuning.py --check' "${DOC_FILE}"
  grep -qF 'sudo uv run scripts/wsl2_ai_tuning.py --apply --mode=nat' "${DOC_FILE}"
}

# ------------------------------------------------------------------------
# scripts/wsl2_ai_tuning.py: PEP 723 inline script metadata
# ------------------------------------------------------------------------

@test "scripts/wsl2_ai_tuning.py declares a uv run --script shebang" {
  first_line="$(head -n 1 "${SCRIPT_FILE}")"
  [ "${first_line}" = '#!/usr/bin/env -S uv run --script' ]
}

@test "scripts/wsl2_ai_tuning.py declares its psutil dependency via PEP 723 inline metadata" {
  grep -qF '# /// script' "${SCRIPT_FILE}"
  grep -qF '#     "psutil",' "${SCRIPT_FILE}"
  grep -qF '# ///' "${SCRIPT_FILE}"
}

# ------------------------------------------------------------------------
# scripts/wsl2_ai_tuning.py: CLI argument validation and combinations
# ------------------------------------------------------------------------

@test "scripts/wsl2_ai_tuning.py rejects an invalid --mode choice" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  run python3 "${SCRIPT_FILE}" --check --mode=bogus
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"invalid choice"* ]]
}

@test "scripts/wsl2_ai_tuning.py rejects an invalid --distro choice" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  run python3 "${SCRIPT_FILE}" --check --distro=windows
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"invalid choice"* ]]
}

@test "scripts/wsl2_ai_tuning.py --apply executes cleanly and reports completion" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  run python3 "${SCRIPT_FILE}" --apply
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Applying System Tuning"* ]]
  [[ "${output}" == *"TUNING COMPLETE"* ]]
}

@test "scripts/wsl2_ai_tuning.py with no flags defaults to --check only (no tuning applied)" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  run python3 "${SCRIPT_FILE}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"System Audit"* ]]
  [[ "${output}" != *"Applying System Tuning"* ]]
}

@test "scripts/wsl2_ai_tuning.py --check reports both the inotify and max_map_count audit lines" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  run python3 "${SCRIPT_FILE}" --check
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"fs.inotify.max_user_watches"* ]]
  [[ "${output}" == *"vm.max_map_count"* ]]
  [[ "${output}" == *"Security Audit"* ]]
}

# ------------------------------------------------------------------------
# docs/REFERENCE_TUNING.md: new "WSL2 AI Performance & Security Tuning
# Guide" resource entry (item 3)
# ------------------------------------------------------------------------

@test "REFERENCE_TUNING.md documents the new WSL2 AI Performance & Security Tuning Guide as resource 3" {
  grep -qF '### 3. WSL2 AI Performance & Security Tuning Guide' "${REFERENCE_TUNING_DOC}"
  grep -qF '[WSL2_AI_PERFORMANCE_TUNING.md](WSL2_AI_PERFORMANCE_TUNING.md)' "${REFERENCE_TUNING_DOC}"
  grep -qF '`scripts/wsl2_ai_tuning.py`' "${REFERENCE_TUNING_DOC}"
}

@test "REFERENCE_TUNING.md's resource 3 entry appears after resource 2 and before the Optimizations section" {
  local resource2_line resource3_line optimizations_line
  resource2_line="$(grep -n -F -- '### 2. Optimizing WSL2 for Claude Code' "${REFERENCE_TUNING_DOC}" | head -1 | cut -d: -f1)"
  resource3_line="$(grep -n -F -- '### 3. WSL2 AI Performance & Security Tuning Guide' "${REFERENCE_TUNING_DOC}" | head -1 | cut -d: -f1)"
  optimizations_line="$(grep -n -F -- '## 🛠️ Optimizations Integrated' "${REFERENCE_TUNING_DOC}" | head -1 | cut -d: -f1)"
  [ -n "${resource2_line}" ]
  [ -n "${resource3_line}" ]
  [ -n "${optimizations_line}" ]
  [ "${resource2_line}" -lt "${resource3_line}" ]
  [ "${resource3_line}" -lt "${optimizations_line}" ]
}

# ------------------------------------------------------------------------
# llms.txt wiring: ordering and uniqueness
# ------------------------------------------------------------------------

@test "llms.txt lists WSL2_AI_PERFORMANCE_TUNING.md between WSL-3NODE-CLUSTER-GUIDE.md and USER_TESTING_FEEDBACK_REVIEW.md" {
  local wsl_line tuning_line review_line
  wsl_line="$(grep -n -F -- '[WSL-3NODE-CLUSTER-GUIDE.md]' "${LLMS_TXT}" | head -1 | cut -d: -f1)"
  tuning_line="$(grep -n -F -- '[WSL2_AI_PERFORMANCE_TUNING.md]' "${LLMS_TXT}" | head -1 | cut -d: -f1)"
  review_line="$(grep -n -F -- '[USER_TESTING_FEEDBACK_REVIEW.md]' "${LLMS_TXT}" | head -1 | cut -d: -f1)"
  [ -n "${wsl_line}" ]
  [ -n "${tuning_line}" ]
  [ -n "${review_line}" ]
  [ "${wsl_line}" -lt "${tuning_line}" ]
  [ "${tuning_line}" -lt "${review_line}" ]
}

@test "llms.txt has exactly one WSL2_AI_PERFORMANCE_TUNING.md entry (no duplicates)" {
  local count
  count="$(grep -cF -- '[WSL2_AI_PERFORMANCE_TUNING.md]' "${LLMS_TXT}")"
  [ "${count}" -eq 1 ]
}

@test "llms.txt's WSL2_AI_PERFORMANCE_TUNING.md link target actually exists in docs/" {
  [ -f "${REPO_ROOT}/docs/WSL2_AI_PERFORMANCE_TUNING.md" ]
}

# ------------------------------------------------------------------------
# mkdocs.yml wiring: ordering and uniqueness
# ------------------------------------------------------------------------

@test "mkdocs.yml registers the WSL2 AI Performance & Security Tuning nav entry pointing at WSL2_AI_PERFORMANCE_TUNING.md" {
  grep -qF -- '- WSL2 AI Performance & Security Tuning: WSL2_AI_PERFORMANCE_TUNING.md' "${MKDOCS_YML}"
}

@test "mkdocs.yml lists WSL2 AI Performance & Security Tuning between the WSL 3-Node Cluster Guide and User Testing Feedback Review entries" {
  local wsl_line tuning_line review_line
  wsl_line="$(grep -n -F -- '- WSL 3-Node Cluster Guide: WSL-3NODE-CLUSTER-GUIDE.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  tuning_line="$(grep -n -F -- '- WSL2 AI Performance & Security Tuning: WSL2_AI_PERFORMANCE_TUNING.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  review_line="$(grep -n -F -- '- User Testing Feedback Review: USER_TESTING_FEEDBACK_REVIEW.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  [ -n "${wsl_line}" ]
  [ -n "${tuning_line}" ]
  [ -n "${review_line}" ]
  [ "${wsl_line}" -lt "${tuning_line}" ]
  [ "${tuning_line}" -lt "${review_line}" ]
}

@test "mkdocs.yml has exactly one WSL2 AI Performance & Security Tuning nav entry (no duplicates)" {
  local count
  count="$(grep -cF -- '- WSL2 AI Performance & Security Tuning: WSL2_AI_PERFORMANCE_TUNING.md' "${MKDOCS_YML}")"
  [ "${count}" -eq 1 ]
}

# ------------------------------------------------------------------------
# sitemap.txt / sitemap.xml wiring: ordering, uniqueness, well-formedness
# ------------------------------------------------------------------------

@test "sitemap.txt lists the WSL2_AI_PERFORMANCE_TUNING URL between WSL-3NODE-CLUSTER-GUIDE and USER_TESTING_FEEDBACK_REVIEW" {
  local wsl_line tuning_line review_line
  wsl_line="$(grep -n -F -- "${BASE_URL}/docs/WSL-3NODE-CLUSTER-GUIDE/" "${SITEMAP_TXT}" | head -1 | cut -d: -f1)"
  tuning_line="$(grep -n -F -- "${BASE_URL}/docs/WSL2_AI_PERFORMANCE_TUNING/" "${SITEMAP_TXT}" | head -1 | cut -d: -f1)"
  review_line="$(grep -n -F -- "${BASE_URL}/docs/USER_TESTING_FEEDBACK_REVIEW/" "${SITEMAP_TXT}" | head -1 | cut -d: -f1)"
  [ -n "${wsl_line}" ]
  [ -n "${tuning_line}" ]
  [ -n "${review_line}" ]
  [ "${wsl_line}" -lt "${tuning_line}" ]
  [ "${tuning_line}" -lt "${review_line}" ]
}

@test "sitemap.txt has exactly one WSL2_AI_PERFORMANCE_TUNING entry (no duplicates)" {
  local count
  count="$(grep -cF -- "${BASE_URL}/docs/WSL2_AI_PERFORMANCE_TUNING/" "${SITEMAP_TXT}")"
  [ "${count}" -eq 1 ]
}

@test "sitemap.xml's WSL2_AI_PERFORMANCE_TUNING <url> block carries weekly/0.80 metadata and sits between WSL-3NODE-CLUSTER-GUIDE and USER_TESTING_FEEDBACK_REVIEW" {
  local wsl_line tuning_line review_line
  wsl_line="$(grep -n -F -- "<loc>${BASE_URL}/docs/WSL-3NODE-CLUSTER-GUIDE/</loc>" "${SITEMAP_XML}" | head -1 | cut -d: -f1)"
  tuning_line="$(grep -n -F -- "<loc>${BASE_URL}/docs/WSL2_AI_PERFORMANCE_TUNING/</loc>" "${SITEMAP_XML}" | head -1 | cut -d: -f1)"
  review_line="$(grep -n -F -- "<loc>${BASE_URL}/docs/USER_TESTING_FEEDBACK_REVIEW/</loc>" "${SITEMAP_XML}" | head -1 | cut -d: -f1)"
  [ -n "${wsl_line}" ]
  [ -n "${tuning_line}" ]
  [ -n "${review_line}" ]
  [ "${wsl_line}" -lt "${tuning_line}" ]
  [ "${tuning_line}" -lt "${review_line}" ]

  local url_block
  url_block="$(awk '
    /<url>/ { block=""; inside=1 }
    inside { block = block "\n" $0 }
    /<\/url>/ {
      if (block ~ "docs/WSL2_AI_PERFORMANCE_TUNING/") { print block; exit }
      inside=0
    }
  ' "${SITEMAP_XML}")"
  echo "${url_block}" | grep -qF '<changefreq>weekly</changefreq>'
  echo "${url_block}" | grep -qF '<priority>0.80</priority>'
}

@test "sitemap.xml is well-formed XML after the new WSL2_AI_PERFORMANCE_TUNING entry was added" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  python3 -c "import xml.etree.ElementTree as ET; ET.parse('${SITEMAP_XML}')"
}
