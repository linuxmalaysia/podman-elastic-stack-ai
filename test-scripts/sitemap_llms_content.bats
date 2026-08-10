#!/usr/bin/env bats
#
# Regression tests for the WSL-3NODE-CLUSTER-GUIDE.md documentation entry
# being wired up consistently across llms.txt, sitemap.txt and sitemap.xml.
# These guard against the three files drifting out of sync (e.g. a new
# sitemap URL added to only one of the two sitemap formats).

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
LLMS="${REPO_ROOT}/llms.txt"
SITEMAP_TXT="${REPO_ROOT}/sitemap.txt"
SITEMAP_XML="${REPO_ROOT}/sitemap.xml"

WSL_GUIDE_URL="https://linuxmalaysia.github.io/podman-elastic-stack-ai/WSL-3NODE-CLUSTER-GUIDE/"

# --- llms.txt --------------------------------------------------------------

@test "llms.txt exists and is readable" {
  [ -f "${LLMS}" ]
  [ -r "${LLMS}" ]
}

@test "llms.txt documents the WSL-3NODE-CLUSTER-GUIDE.md entry with its description" {
  grep -qF -- '- [WSL-3NODE-CLUSTER-GUIDE.md](WSL-3NODE-CLUSTER-GUIDE.md): Step-by-step guide to run a fully functional 3-Node Elasticsearch Cluster + Kibana configuration on Windows Subsystem for Linux (WSL2) using Podman.' "${LLMS}"
}

# --- sitemap.txt -------------------------------------------------------

@test "sitemap.txt exists and is readable" {
  [ -f "${SITEMAP_TXT}" ]
  [ -r "${SITEMAP_TXT}" ]
}

@test "sitemap.txt lists the WSL-3NODE-CLUSTER-GUIDE page URL" {
  grep -qF "${WSL_GUIDE_URL}" "${SITEMAP_TXT}"
}

# --- sitemap.xml -------------------------------------------------------

@test "sitemap.xml exists and is readable" {
  [ -f "${SITEMAP_XML}" ]
  [ -r "${SITEMAP_XML}" ]
}

@test "sitemap.xml is well-formed XML" {
  run python3 -c "import xml.etree.ElementTree as ET; ET.parse('${SITEMAP_XML}')"
  [ "${status}" -eq 0 ]
}

@test "sitemap.xml contains a url entry for the WSL-3NODE-CLUSTER-GUIDE page with weekly/0.80 metadata" {
  run python3 - "${SITEMAP_XML}" "${WSL_GUIDE_URL}" <<'PY'
import sys
import xml.etree.ElementTree as ET

xml_path, target = sys.argv[1], sys.argv[2]
ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
tree = ET.parse(xml_path)

for url in tree.getroot().findall("sm:url", ns):
    loc = url.find("sm:loc", ns).text
    if loc == target:
        changefreq = url.find("sm:changefreq", ns).text
        priority = url.find("sm:priority", ns).text
        if changefreq != "weekly" or priority != "0.80":
            sys.exit(1)
        sys.exit(0)

sys.exit(1)
PY
  [ "${status}" -eq 0 ]
}

# --- cross-file consistency ---------------------------------------------

@test "sitemap.txt and sitemap.xml stay in sync (identical set of URLs)" {
  run python3 - "${SITEMAP_XML}" "${SITEMAP_TXT}" <<'PY'
import sys
import xml.etree.ElementTree as ET

xml_path, txt_path = sys.argv[1], sys.argv[2]
ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
tree = ET.parse(xml_path)

xml_urls = {u.find("sm:loc", ns).text for u in tree.getroot().findall("sm:url", ns)}
with open(txt_path) as f:
    txt_urls = {line.strip() for line in f if line.strip()}

if xml_urls != txt_urls:
    sys.stderr.write(f"only in xml: {xml_urls - txt_urls}\n")
    sys.stderr.write(f"only in txt: {txt_urls - xml_urls}\n")
    sys.exit(1)
PY
  [ "${status}" -eq 0 ]
}