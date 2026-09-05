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

@test "docs/UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md contains valid OKF v0.2 YAML frontmatter metadata" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"

  python3 -c "
import sys, yaml

with open('${PLAYBOOK_DOC}', 'r') as f:
    lines = f.readlines()

assert lines[0].strip() == '---', 'First line must be frontmatter start ---'
end_idx = None
for i in range(1, len(lines)):
    if lines[i].strip() == '---':
        end_idx = i
        break

assert end_idx is not None, 'Closing frontmatter --- not found'
frontmatter_str = ''.join(lines[1:end_idx])
data = yaml.safe_load(frontmatter_str)

assert str(data.get('okf_version')) in ['0.1', '0.2'], 'Invalid okf_version'
assert data.get('type') == 'operations', 'Type must be operations'
assert 'title' in data and isinstance(data['title'], str), 'Missing title'
assert 'author' in data and isinstance(data['author'], str), 'Missing author'
assert 'timestamp' in data or 'date' in data, 'Missing timestamp/date'
assert isinstance(data.get('topics'), list) and len(data['topics']) > 0, 'Missing or empty topics list'
"
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

@test "docs/UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md documents all top-level sections in order outside code blocks" {
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
    line="$(awk -v h="${header}" '
      /^```/ { in_code = !in_code; next }
      !in_code && $0 == h { print NR; exit }
    ' "${PLAYBOOK_DOC}")"
    [ -n "${line}" ]
    [ "${line}" -gt "${prev_line}" ]
    prev_line="${line}"
  done
}

@test "mkdocs.yml registers the Universal Operational Replication Playbook nav entry with full label mapping" {
  grep -qF -- '- Universal Operational Replication & Prompt Playbook: UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md' "${MKDOCS_YML}"
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
