#!/usr/bin/env bats
#
# Regression tests for sitemap.txt and sitemap.xml, ensuring the relocated
# guide documentation URLs were updated to the docs/ path segment, that the
# new GITEA_GUIDE URL was added, and that sitemap.xml remains well-formed.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SITEMAP_TXT="${REPO_ROOT}/sitemap.txt"
SITEMAP_XML="${REPO_ROOT}/sitemap.xml"
BASE_URL="https://linuxmalaysia.github.io/podman-elastic-stack-ai"

@test "sitemap.txt exists and is readable" {
  [ -f "${SITEMAP_TXT}" ]
  [ -r "${SITEMAP_TXT}" ]
}

@test "sitemap.xml exists and is readable" {
  [ -f "${SITEMAP_XML}" ]
  [ -r "${SITEMAP_XML}" ]
}

@test "sitemap.txt lists the relocated guide URLs under the docs/ path segment" {
  grep -qF "${BASE_URL}/docs/INSTALL/" "${SITEMAP_TXT}"
  grep -qF "${BASE_URL}/docs/PLAYBOOKS/" "${SITEMAP_TXT}"
  grep -qF "${BASE_URL}/docs/LOCAL_DEVELOPMENT_FEEDBACK_GUIDE/" "${SITEMAP_TXT}"
  grep -qF "${BASE_URL}/docs/DOCS_MATRIX_TELEMETRY/" "${SITEMAP_TXT}"
  grep -qF "${BASE_URL}/docs/WSL-3NODE-CLUSTER-GUIDE/" "${SITEMAP_TXT}"
}

@test "sitemap.txt includes the new GITEA_GUIDE URL under docs/" {
  grep -qF "${BASE_URL}/docs/GITEA_GUIDE/" "${SITEMAP_TXT}"
}

@test "sitemap.txt keeps HISTORY and CHANGELOG URLs at the root (not under docs/)" {
  grep -qF "${BASE_URL}/HISTORY/" "${SITEMAP_TXT}"
  grep -qF "${BASE_URL}/CHANGELOG/" "${SITEMAP_TXT}"
}

@test "sitemap.txt no longer lists stale root-level URLs for the relocated guide docs" {
  # Regression guard: prior to this PR, these URLs had no docs/ path
  # segment (e.g. ".../podman-elastic-stack-ai/INSTALL/"). Ensure the
  # outdated root-level URL form is gone for each relocated file.
  for slug in INSTALL PLAYBOOKS LOCAL_DEVELOPMENT_FEEDBACK_GUIDE DOCS_MATRIX_TELEMETRY WSL-3NODE-CLUSTER-GUIDE; do
    run grep -qF "${BASE_URL}/${slug}/" "${SITEMAP_TXT}"
    [ "${status}" -ne 0 ]
  done
}

@test "sitemap.txt has exactly nine URLs (homepage + 6 relocated docs + HISTORY + CHANGELOG)" {
  local count
  count="$(grep -cF "${BASE_URL}" "${SITEMAP_TXT}")"
  [ "${count}" -eq 9 ]
}

@test "sitemap.xml lists the relocated guide URLs under the docs/ path segment" {
  grep -qF "<loc>${BASE_URL}/docs/INSTALL/</loc>" "${SITEMAP_XML}"
  grep -qF "<loc>${BASE_URL}/docs/PLAYBOOKS/</loc>" "${SITEMAP_XML}"
  grep -qF "<loc>${BASE_URL}/docs/LOCAL_DEVELOPMENT_FEEDBACK_GUIDE/</loc>" "${SITEMAP_XML}"
  grep -qF "<loc>${BASE_URL}/docs/DOCS_MATRIX_TELEMETRY/</loc>" "${SITEMAP_XML}"
  grep -qF "<loc>${BASE_URL}/docs/WSL-3NODE-CLUSTER-GUIDE/</loc>" "${SITEMAP_XML}"
}

@test "sitemap.xml includes a new <url> entry for GITEA_GUIDE with changefreq/priority metadata" {
  grep -qF "<loc>${BASE_URL}/docs/GITEA_GUIDE/</loc>" "${SITEMAP_XML}"
  # The GITEA_GUIDE entry should carry the same weekly/0.80 metadata as the
  # other secondary-doc entries.
  awk '/docs\/GITEA_GUIDE\// { found=1 } found && /<changefreq>/ { print; exit }' "${SITEMAP_XML}" | grep -qF 'weekly'
  awk '/docs\/GITEA_GUIDE\// { found=1 } found && /<priority>/ { print; exit }' "${SITEMAP_XML}" | grep -qF '0.80'
}

@test "sitemap.xml no longer lists stale root-level <loc> entries for the relocated guide docs" {
  for slug in INSTALL PLAYBOOKS LOCAL_DEVELOPMENT_FEEDBACK_GUIDE DOCS_MATRIX_TELEMETRY WSL-3NODE-CLUSTER-GUIDE; do
    run grep -qF "<loc>${BASE_URL}/${slug}/</loc>" "${SITEMAP_XML}"
    [ "${status}" -ne 0 ]
  done
}

@test "sitemap.xml is well-formed XML" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  python3 -c "import xml.etree.ElementTree as ET; ET.parse('${SITEMAP_XML}')"
}

@test "sitemap.xml contains exactly nine <url> entries matching sitemap.txt" {
  local count
  count="$(grep -cF '<url>' "${SITEMAP_XML}")"
  [ "${count}" -eq 9 ]
}