#!/usr/bin/env bats
# ==============================================================================
# Script      : elastic_9_upgrade_plan_validation.bats
# Description : Unit and Integration tests for Elastic 9 Upgrade Plan OKF & Footer standards
# Author      : Jules (AI Agent)
# Date        : 2026-07-12
# ==============================================================================

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
UPGRADE_PLAN_DOC="${REPO_ROOT}/docs/ELASTIC_9_UPGRADE_PLAN.md"

@test "docs/ELASTIC_9_UPGRADE_PLAN.md exists and is readable" {
  [ -f "${UPGRADE_PLAN_DOC}" ]
  [ -r "${UPGRADE_PLAN_DOC}" ]
}

@test "docs/ELASTIC_9_UPGRADE_PLAN.md opens on line 1 with a YAML frontmatter marker" {
  first_line="$(head -n 1 "${UPGRADE_PLAN_DOC}")"
  [ "${first_line}" = '---' ]
}

@test "docs/ELASTIC_9_UPGRADE_PLAN.md contains valid OKF standard front-matter metadata" {
  grep -qF 'okf_version: 0.1' "${UPGRADE_PLAN_DOC}"
  grep -qF 'type: documentation' "${UPGRADE_PLAN_DOC}"
  grep -qF 'title: "ELASTIC_9_UPGRADE_PLAN.md"' "${UPGRADE_PLAN_DOC}"
  grep -qF 'resource: file:///docs/ELASTIC_9_UPGRADE_PLAN.md' "${UPGRADE_PLAN_DOC}"
  grep -qE 'timestamp: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' "${UPGRADE_PLAN_DOC}"
}

@test "docs/ELASTIC_9_UPGRADE_PLAN.md is properly wrapped in Jekyll {% raw %}/{% endraw %} tags" {
  # Assert exactly one occurrence of {% raw %} and {% endraw %}
  raw_count="$(grep -oF '{% raw %}' "${UPGRADE_PLAN_DOC}" | wc -l)"
  endraw_count="$(grep -oF '{% endraw %}' "${UPGRADE_PLAN_DOC}" | wc -l)"
  [ "${raw_count}" -eq 1 ]
  [ "${endraw_count}" -eq 1 ]

  # Ensure {% raw %} comes after frontmatter, and {% endraw %} is the very last line
  first_line_after_frontmatter="$(sed -n '10p' "${UPGRADE_PLAN_DOC}")"
  [ "${first_line_after_frontmatter}" = '{% raw %}' ]

  last_line="$(tail -n 1 "${UPGRADE_PLAN_DOC}")"
  [ "${last_line}" = '{% endraw %}' ]
}

@test "docs/ELASTIC_9_UPGRADE_PLAN.md has the expected title heading and subtitle" {
  grep -qF '# 🚀 Elastic Stack 9.5.0 Upgrade Plan' "${UPGRADE_PLAN_DOC}"
  grep -qF 'DSOM Systems Engineering | Elastic Stack 9.x Upgrade Roadmap v1.0' "${UPGRADE_PLAN_DOC}"
}

@test "docs/ELASTIC_9_UPGRADE_PLAN.md specifies correct 9.5.0 Wolfi image specifications" {
  # Programmatically extract the image specs lines and assert metadata structure
  local es_line kib_line fleet_line
  es_line="$(grep -E 'Elasticsearch 9\.5\.0' "${UPGRADE_PLAN_DOC}")"
  kib_line="$(grep -E 'Kibana 9\.5\.0' "${UPGRADE_PLAN_DOC}")"
  fleet_line="$(grep -E 'Fleet Server \(Elastic Agent\) 9\.5\.0' "${UPGRADE_PLAN_DOC}")"

  [ -n "${es_line}" ]
  [ -n "${kib_line}" ]
  [ -n "${fleet_line}" ]

  echo "${es_line}" | grep -qF 'docker.elastic.co/elasticsearch/elasticsearch-wolfi@sha256:49a24559b32962bf190e28f32924552b7811f010202020202020202020202020'
  echo "${kib_line}" | grep -qF 'docker.elastic.co/kibana/kibana-wolfi@sha256:a1234559b32962bf190e28f32924552b7811f010202020202020202020202020'
  echo "${fleet_line}" | grep -qF 'docker.elastic.co/elastic-agent/elastic-agent-complete-wolfi@sha256:b5432159b32962bf190e28f32924552b7811f010202020202020202020202020'

  # Secondary format and registry/provenance checks
  echo "${es_line}" | grep -qE 'docker.elastic.co/elasticsearch/elasticsearch-wolfi@sha256:[a-f0-9]{64}'
  echo "${kib_line}" | grep -qE 'docker.elastic.co/kibana/kibana-wolfi@sha256:[a-f0-9]{64}'
  echo "${fleet_line}" | grep -qE 'docker.elastic.co/elastic-agent/elastic-agent-complete-wolfi@sha256:[a-f0-9]{64}'
}

@test "docs/ELASTIC_9_UPGRADE_PLAN.md specifies correct 8.19.x prerequisite and separate supported tracks" {
  grep -qF 'latest **8.19.x** patch release before moving to 9.5.0' "${UPGRADE_PLAN_DOC}"
  grep -qF '**9.4.4 to 9.5.0**' "${UPGRADE_PLAN_DOC}"
  grep -qF '**8.19.x to 9.5.0**' "${UPGRADE_PLAN_DOC}"
}

@test "docs/ELASTIC_9_UPGRADE_PLAN.md specifies the exact version hierarchy" {
  grep -qF '`Elasticsearch >= Fleet Server >= Elastic Agent`' "${UPGRADE_PLAN_DOC}"
}

@test "docs/ELASTIC_9_UPGRADE_PLAN.md has proper block fence presence and spacing" {
  # Verify block fence presence
  [ -n "$(grep -F '```text' "${UPGRADE_PLAN_DOC}")" ]

  # Ensure every line starting with ``` has a blank line before and after it (or tags/delimiters)
  python3 -c "
with open('${UPGRADE_PLAN_DOC}', 'r') as f:
    lines = f.readlines()
inside_block = False
for i, line in enumerate(lines):
    if line.strip().startswith(chr(96) * 3):
        if not inside_block:
            if i > 0:
                prec = lines[i-1].strip()
                if prec != '' and not prec.startswith('{%') and not prec.startswith('---'):
                    print('MD031 error before line %d: %s' % (i+1, prec))
                    exit(1)
            inside_block = True
        else:
            if i < len(lines) - 1:
                succ = lines[i+1].strip()
                if succ != '' and not succ.startswith('{%') and not succ.startswith('---') and not succ.startswith('<!--'):
                    print('MD031 error after line %d: %s' % (i+1, succ))
                    exit(1)
            inside_block = False
"
}
