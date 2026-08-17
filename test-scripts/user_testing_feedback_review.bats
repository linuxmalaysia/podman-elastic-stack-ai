#!/usr/bin/env bats
#
# Regression tests for the new docs/USER_TESTING_FEEDBACK_REVIEW.md document
# and its wiring into llms.txt, mkdocs.yml, sitemap.txt, and sitemap.xml.
# These guard against the new document's frontmatter, content, and
# navigation/sitemap registration silently drifting or being reverted.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
DOC="${REPO_ROOT}/docs/USER_TESTING_FEEDBACK_REVIEW.md"
LLMS_TXT="${REPO_ROOT}/llms.txt"
MKDOCS_YML="${REPO_ROOT}/mkdocs.yml"
SITEMAP_TXT="${REPO_ROOT}/sitemap.txt"
SITEMAP_XML="${REPO_ROOT}/sitemap.xml"
BASE_URL="https://linuxmalaysia.github.io/podman-elastic-stack-ai"

# ------------------------------------------------------------------------
# docs/USER_TESTING_FEEDBACK_REVIEW.md
# ------------------------------------------------------------------------

@test "USER_TESTING_FEEDBACK_REVIEW.md exists and is readable" {
  [ -f "${DOC}" ]
  [ -r "${DOC}" ]
}

@test "USER_TESTING_FEEDBACK_REVIEW.md opens on line 1 with a YAML frontmatter marker" {
  first_line="$(head -n 1 "${DOC}")"
  [ "${first_line}" = '---' ]
}

@test "USER_TESTING_FEEDBACK_REVIEW.md's second frontmatter delimiter appears on line 9, right before the title" {
  # Regression guard: the document also uses bare '---' as a horizontal-rule
  # separator between sections further down, so this pins down the specific
  # line where the *closing* frontmatter marker sits, distinct from those
  # later horizontal rules.
  local marker2_line
  marker2_line="$(grep -n '^---$' "${DOC}" | sed -n '2p' | cut -d: -f1)"
  [ "${marker2_line}" -eq 9 ]
}

@test "USER_TESTING_FEEDBACK_REVIEW.md frontmatter declares the expected OKF metadata fields" {
  frontmatter="$(awk 'BEGIN {show=0; count=0} /^---$/ {count++; if(count==1) {show=1; next} if(count==2) {show=0; exit}} show {print}' "${DOC}")"

  echo "${frontmatter}" | grep -Fxq 'okf_version: 0.1'
  echo "${frontmatter}" | grep -Fxq 'type: documentation'
  echo "${frontmatter}" | grep -Fxq 'title: "USER_TESTING_FEEDBACK_REVIEW.md"'
  echo "${frontmatter}" | grep -Fxq 'description: "Review and analysis of user testing findings report on WSL2 notebook deployment."'
  echo "${frontmatter}" | grep -Fxq 'resource: file:///docs/USER_TESTING_FEEDBACK_REVIEW.md'
}

@test "USER_TESTING_FEEDBACK_REVIEW.md frontmatter topics field is a well-formed bracketed list" {
  frontmatter="$(awk 'BEGIN {show=0; count=0} /^---$/ {count++; if(count==1) {show=1; next} if(count==2) {show=0; exit}} show {print}' "${DOC}")"
  echo "${frontmatter}" | grep -q '^topics: \[[a-z0-9, -]*\]$'
  echo "${frontmatter}" | grep -Fxq 'topics: [dsom, testing, wsl2, podman, elasticsearch, review]'
}

@test "USER_TESTING_FEEDBACK_REVIEW.md frontmatter declares an ISO-8601 timestamp field" {
  frontmatter="$(awk 'BEGIN {show=0; count=0} /^---$/ {count++; if(count==1) {show=1; next} if(count==2) {show=0; exit}} show {print}' "${DOC}")"
  echo "${frontmatter}" | grep -qE '^timestamp: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
}

@test "USER_TESTING_FEEDBACK_REVIEW.md's title heading immediately follows the closing frontmatter marker" {
  marker2_line="$(grep -n '^---$' "${DOC}" | sed -n '2p' | cut -d: -f1)"
  [ -n "${marker2_line}" ]
  local next_line
  next_line="$(sed -n "$((marker2_line + 1))p" "${DOC}")"
  [ "${next_line}" = '# 📊 User Testing Feedback Review & Action Plan' ]
}

@test "USER_TESTING_FEEDBACK_REVIEW.md documents all four top-level sections in order" {
  headers=(
    '## 1. Executive Overview'
    '## 2. Technical Evaluation of Reported Issues'
    '## 3. Review of Recommendations & Operational Action Items'
    '## 4. Conclusion'
  )
  local prev_line=0
  for header in "${headers[@]}"; do
    line="$(grep -n -F -- "${header}" "${DOC}" | head -1 | cut -d: -f1)"
    [ -n "${line}" ]
    [ "${line}" -gt "${prev_line}" ]
    prev_line="${line}"
  done
}

@test "USER_TESTING_FEEDBACK_REVIEW.md references the tester name and testing date" {
  grep -qF -- '**Skywalker** (dated 12 August 2026)' "${DOC}"
}

@test "USER_TESTING_FEEDBACK_REVIEW.md's issues table documents exactly nine numbered issues" {
  local count
  count="$(grep -cE -- '^\| \*\*[0-9]\*\* \|' "${DOC}")"
  [ "${count}" -eq 9 ]
}

@test "USER_TESTING_FEEDBACK_REVIEW.md's issues table marks every row as addressed" {
  # Regression guard: every row of the technical evaluation table should
  # carry an "Addressed" status (either "Addressed" or "Addressed via Docs").
  local count
  count="$(grep -cE -- '^\| \*\*[0-9]\*\* \|.*\*\*Addressed' "${DOC}")"
  [ "${count}" -eq 9 ]
}

@test "USER_TESTING_FEEDBACK_REVIEW.md documents all four operational recommendations in order" {
  headers=(
    '### Recommendation 1: Hardware System Requirements Guidance'
    '### Recommendation 2: Playbook Hardening for Rootless & Security'
    '### Recommendation 3: Repository URL & Documentation Consistency'
    '### Recommendation 4: Deployment Mode Selection Guidance'
  )
  local prev_line=0
  for header in "${headers[@]}"; do
    line="$(grep -n -F -- "${header}" "${DOC}" | head -1 | cut -d: -f1)"
    [ -n "${line}" ]
    [ "${line}" -gt "${prev_line}" ]
    prev_line="${line}"
  done
}

@test "USER_TESTING_FEEDBACK_REVIEW.md's Recommendation 3 references the canonical repository URL" {
  local rec3_line rec4_line url_line
  rec3_line="$(grep -n -F -- '### Recommendation 3: Repository URL & Documentation Consistency' "${DOC}" | head -1 | cut -d: -f1)"
  rec4_line="$(grep -n -F -- '### Recommendation 4: Deployment Mode Selection Guidance' "${DOC}" | head -1 | cut -d: -f1)"
  url_line="$(grep -n -F -- 'https://github.com/linuxmalaysia/podman-elastic-stack-ai.git' "${DOC}" | head -1 | cut -d: -f1)"
  [ -n "${rec3_line}" ]
  [ -n "${rec4_line}" ]
  [ -n "${url_line}" ]
  [ "${url_line}" -gt "${rec3_line}" ]
  [ "${url_line}" -lt "${rec4_line}" ]
}

@test "USER_TESTING_FEEDBACK_REVIEW.md's conclusion summarizes that all nine issues were addressed" {
  grep -qF -- 'All nine identified issues have been analyzed, addressed, and incorporated' "${DOC}"
}

@test "USER_TESTING_FEEDBACK_REVIEW.md is not wrapped in Jekyll {% raw %}/{% endraw %} tags" {
  # Unlike the Jinja2/Ansible-heavy adopted guides, this document contains no
  # double-curly-brace template syntax, so it should not carry the raw/endraw
  # wrapping used elsewhere to shield such syntax from Jekyll's Liquid engine.
  run grep -qF -- '{% raw %}' "${DOC}"
  [ "${status}" -ne 0 ]
  run grep -qF -- '{% endraw %}' "${DOC}"
  [ "${status}" -ne 0 ]
}

# ------------------------------------------------------------------------
# llms.txt wiring
# ------------------------------------------------------------------------

@test "llms.txt documents the new USER_TESTING_FEEDBACK_REVIEW.md entry under docs/" {
  grep -qF -- '[USER_TESTING_FEEDBACK_REVIEW.md](docs/USER_TESTING_FEEDBACK_REVIEW.md): Review and technical analysis of user testing findings report on WSL2 notebook deployment.' "${LLMS_TXT}"
}

@test "llms.txt lists USER_TESTING_FEEDBACK_REVIEW.md after WSL-3NODE-CLUSTER-GUIDE.md and before GITEA_GUIDE.md" {
  local wsl_line review_line gitea_line
  wsl_line="$(grep -n -F -- '[WSL-3NODE-CLUSTER-GUIDE.md]' "${LLMS_TXT}" | head -1 | cut -d: -f1)"
  review_line="$(grep -n -F -- '[USER_TESTING_FEEDBACK_REVIEW.md]' "${LLMS_TXT}" | head -1 | cut -d: -f1)"
  gitea_line="$(grep -n -F -- '[GITEA_GUIDE.md]' "${LLMS_TXT}" | head -1 | cut -d: -f1)"
  [ -n "${wsl_line}" ]
  [ -n "${review_line}" ]
  [ -n "${gitea_line}" ]
  [ "${review_line}" -gt "${wsl_line}" ]
  [ "${review_line}" -lt "${gitea_line}" ]
}

@test "llms.txt has exactly one USER_TESTING_FEEDBACK_REVIEW.md entry (no duplicates)" {
  local count
  count="$(grep -cF -- '[USER_TESTING_FEEDBACK_REVIEW.md]' "${LLMS_TXT}")"
  [ "${count}" -eq 1 ]
}

@test "llms.txt's USER_TESTING_FEEDBACK_REVIEW.md link target actually exists in docs/" {
  [ -f "${REPO_ROOT}/docs/USER_TESTING_FEEDBACK_REVIEW.md" ]
}

# ------------------------------------------------------------------------
# mkdocs.yml wiring
# ------------------------------------------------------------------------

@test "mkdocs.yml registers the User Testing Feedback Review nav entry pointing at USER_TESTING_FEEDBACK_REVIEW.md" {
  grep -qF -- '- User Testing Feedback Review: USER_TESTING_FEEDBACK_REVIEW.md' "${MKDOCS_YML}"
}

@test "mkdocs.yml lists User Testing Feedback Review between the WSL 3-Node Cluster Guide and Upgrade Plan to Elastic 9.x entries" {
  local wsl_line review_line upgrade_line
  wsl_line="$(grep -n -F -- '- WSL 3-Node Cluster Guide: WSL-3NODE-CLUSTER-GUIDE.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  review_line="$(grep -n -F -- '- User Testing Feedback Review: USER_TESTING_FEEDBACK_REVIEW.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"
  upgrade_line="$(grep -n -F -- '- Upgrade Plan to Elastic 9.x: ELASTIC_9_UPGRADE_PLAN.md' "${MKDOCS_YML}" | head -1 | cut -d: -f1)"

  [ -n "${wsl_line}" ]
  [ -n "${review_line}" ]
  [ -n "${upgrade_line}" ]
  [ "${wsl_line}" -lt "${review_line}" ]
  [ "${review_line}" -lt "${upgrade_line}" ]
}

@test "mkdocs.yml has exactly one User Testing Feedback Review nav entry (no duplicates)" {
  local count
  count="$(grep -cF -- '- User Testing Feedback Review: USER_TESTING_FEEDBACK_REVIEW.md' "${MKDOCS_YML}")"
  [ "${count}" -eq 1 ]
}

# ------------------------------------------------------------------------
# sitemap.txt / sitemap.xml wiring
# ------------------------------------------------------------------------

@test "sitemap.txt includes the new USER_TESTING_FEEDBACK_REVIEW URL under docs/" {
  grep -qF -- "${BASE_URL}/docs/USER_TESTING_FEEDBACK_REVIEW/" "${SITEMAP_TXT}"
}

@test "sitemap.txt lists the USER_TESTING_FEEDBACK_REVIEW URL between WSL-3NODE-CLUSTER-GUIDE and REFERENCE_TUNING" {
  local wsl_line review_line reference_line
  wsl_line="$(grep -n -F -- "${BASE_URL}/docs/WSL-3NODE-CLUSTER-GUIDE/" "${SITEMAP_TXT}" | head -1 | cut -d: -f1)"
  review_line="$(grep -n -F -- "${BASE_URL}/docs/USER_TESTING_FEEDBACK_REVIEW/" "${SITEMAP_TXT}" | head -1 | cut -d: -f1)"
  reference_line="$(grep -n -F -- "${BASE_URL}/docs/REFERENCE_TUNING/" "${SITEMAP_TXT}" | head -1 | cut -d: -f1)"

  [ -n "${wsl_line}" ]
  [ -n "${review_line}" ]
  [ -n "${reference_line}" ]
  [ "${wsl_line}" -lt "${review_line}" ]
  [ "${review_line}" -lt "${reference_line}" ]
}

@test "sitemap.xml includes a new <url> entry for USER_TESTING_FEEDBACK_REVIEW with weekly/0.80 metadata" {
  grep -qF -- "<loc>${BASE_URL}/docs/USER_TESTING_FEEDBACK_REVIEW/</loc>" "${SITEMAP_XML}"
  local url_block
  url_block="$(awk '
    /<url>/ { block=""; inside=1 }
    inside { block = block "\n" $0 }
    /<\/url>/ {
      if (block ~ "docs/USER_TESTING_FEEDBACK_REVIEW/") { print block; exit }
      inside=0
    }
  ' "${SITEMAP_XML}")"
  echo "${url_block}" | grep -qF -- '<changefreq>weekly</changefreq>'
  echo "${url_block}" | grep -qF -- '<priority>0.80</priority>'
}

@test "sitemap.xml's USER_TESTING_FEEDBACK_REVIEW <url> block appears between the WSL-3NODE-CLUSTER-GUIDE and REFERENCE_TUNING blocks" {
  local wsl_line review_line reference_line
  wsl_line="$(grep -n -F -- "<loc>${BASE_URL}/docs/WSL-3NODE-CLUSTER-GUIDE/</loc>" "${SITEMAP_XML}" | head -1 | cut -d: -f1)"
  review_line="$(grep -n -F -- "<loc>${BASE_URL}/docs/USER_TESTING_FEEDBACK_REVIEW/</loc>" "${SITEMAP_XML}" | head -1 | cut -d: -f1)"
  reference_line="$(grep -n -F -- "<loc>${BASE_URL}/docs/REFERENCE_TUNING/</loc>" "${SITEMAP_XML}" | head -1 | cut -d: -f1)"

  [ -n "${wsl_line}" ]
  [ -n "${review_line}" ]
  [ -n "${reference_line}" ]
  [ "${wsl_line}" -lt "${review_line}" ]
  [ "${review_line}" -lt "${reference_line}" ]
}

@test "sitemap.xml is still well-formed XML after the new USER_TESTING_FEEDBACK_REVIEW entry was added" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  python3 -c "import xml.etree.ElementTree as ET; ET.parse('${SITEMAP_XML}')"
}

@test "sitemap.txt and sitemap.xml both have exactly one USER_TESTING_FEEDBACK_REVIEW entry (no duplicates)" {
  local txt_count xml_count
  txt_count="$(grep -cF -- "${BASE_URL}/docs/USER_TESTING_FEEDBACK_REVIEW/" "${SITEMAP_TXT}")"
  xml_count="$(grep -cF -- "<loc>${BASE_URL}/docs/USER_TESTING_FEEDBACK_REVIEW/</loc>" "${SITEMAP_XML}")"
  [ "${txt_count}" -eq 1 ]
  [ "${xml_count}" -eq 1 ]
}

@test "sitemap.xml's <loc> entries exactly match the URL set listed in sitemap.txt, including the new entry" {
  local txt_urls xml_urls
  txt_urls="$(grep -F -- "${BASE_URL}" "${SITEMAP_TXT}" | sort)"
  xml_urls="$(grep -oE -- '<loc>[^<]+</loc>' "${SITEMAP_XML}" | sed -E 's#<loc>(.*)</loc>#\1#' | sort)"
  [ "${txt_urls}" = "${xml_urls}" ]
}