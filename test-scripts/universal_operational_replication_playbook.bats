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

extract_playbook_yaml() {
  local playbook_name="$1"
  awk -v playbook_name="${playbook_name}" '
    index($0, "(`" playbook_name "`)") { found_heading = 1; next }
    found_heading && /^```yaml$/ { in_yaml = 1; next }
    in_yaml && /^```$/ { exit }
    in_yaml { print }
  ' "${PLAYBOOK_DOC}"
}

extract_all_playbook_yaml() {
  awk '
    /^```yaml$/ { in_yaml = 1; next }
    in_yaml && /^```$/ { in_yaml = 0; next }
    in_yaml { print }
  ' "${PLAYBOOK_DOC}"
}

@test "docs/UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md exists and is readable" {
  [ -f "${PLAYBOOK_DOC}" ]
  [ -r "${PLAYBOOK_DOC}" ]
}

@test "docs/UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md opens on line 1 with a YAML frontmatter marker" {
  first_line="$(head -n 1 "${PLAYBOOK_DOC}")"
  [ "${first_line}" = '---' ]
}

@test "docs/UNIVERSAL_OPERATIONAL_REPLICATION_PLAYBOOK.md contains exact required OKF v0.2 frontmatter" {
  frontmatter="$(awk '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter { print }
  ' "${PLAYBOOK_DOC}")"

  grep -qxF 'okf_version: "0.2"' <<<"${frontmatter}"
  grep -qxF 'type: "operations"' <<<"${frontmatter}"
  grep -qxF 'title: "Universal Operational Replication & Prompt Playbook: Elastic Stack SOC Infrastructure Upgrade & Automation Fabric"' <<<"${frontmatter}"
  grep -qxF 'author: "Antigravity Cognitive Digital Twin & Lead SOC Architect"' <<<"${frontmatter}"
  grep -qxF 'timestamp: "2026-09-05T00:00:00Z"' <<<"${frontmatter}"
  grep -qxF 'classification: "Universal Engineering Standard / Operational Playbook"' <<<"${frontmatter}"

  topics="$(awk '
    /^topics:$/ { in_topics = 1; next }
    in_topics && /^  - / { sub(/^  - /, ""); print; next }
    in_topics { exit }
  ' <<<"${frontmatter}")"
  expected_topics="$(printf '%s\n' \
    elasticsearch kibana fleet logstash kafka semaphoreui ara ansible \
    prompt-engineering zero-downtime-upgrade)"
  [ "${topics}" = "${expected_topics}" ]
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

@test "the declarative suite contains exactly eight named and closed YAML playbook examples" {
  [ "$(grep -c '^### Playbook [1-8]:' "${PLAYBOOK_DOC}")" -eq 8 ]
  [ "$(grep -c '^```yaml$' "${PLAYBOOK_DOC}")" -eq 8 ]

  fence_count="$(grep -c '^```' "${PLAYBOOK_DOC}")"
  [ "$((fence_count % 2))" -eq 0 ]

  for playbook_name in \
    upgrade-preflight.yml \
    upgrade-elasticsearch.yml \
    upgrade-kibana.yml \
    scale-kafka-partitions.yml \
    upgrade-fleet-integrations.yml \
    backup-semaphore-podman.yml \
    deploy-ara-podman.yml \
    upgrade-postflight-validation.yml; do
    [ -n "$(extract_playbook_yaml "${playbook_name}")" ]
  done
}

@test "every Ansible URI task in the playbook suite verifies TLS with the configured CA" {
  all_yaml="$(extract_all_playbook_yaml)"
  uri_count="$(grep -c 'ansible\.builtin\.uri:' <<<"${all_yaml}")"
  [ "${uri_count}" -gt 0 ]

  awk '
    /^[[:space:]]+- name:/ {
      if (in_uri && !has_ca_path) missing_ca = 1
      in_uri = 0
      has_ca_path = 0
    }
    /ansible\.builtin\.uri:/ { in_uri = 1 }
    in_uri && /ca_path: "\{\{ ca_cert_path \}\}"/ { has_ca_path = 1 }
    END {
      if (in_uri && !has_ca_path) missing_ca = 1
      exit missing_ca
    }
  ' <<<"${all_yaml}"

  run grep -E 'validate_certs:[[:space:]]*(no|false)' <<<"${all_yaml}"
  [ "${status}" -eq 1 ]
}

@test "Elasticsearch rolling upgrades are serial and restore cluster state on failure" {
  playbook="$(extract_playbook_yaml upgrade-elasticsearch.yml)"

  [ "$(grep -c 'serial: 1' <<<"${playbook}")" -eq 2 ]
  grep -qF 'block:' <<<"${playbook}"
  grep -qF 'rescue:' <<<"${playbook}"
  grep -qF 'always:' <<<"${playbook}"
  grep -qF 'cluster.routing.allocation.enable: "primaries"' <<<"${playbook}"
  grep -qF 'cluster.routing.allocation.enable: null' <<<"${playbook}"
  grep -qF '_ml/set_upgrade_mode?enabled=true' <<<"${playbook}"
  grep -qF '_ml/set_upgrade_mode?enabled=false' <<<"${playbook}"
  grep -qF 'health_convergence.json.unassigned_shards == 0' <<<"${playbook}"
}

@test "Elasticsearch master discovery protects the elected master during the replica pass" {
  playbook="$(extract_playbook_yaml upgrade-elasticsearch.yml)"

  grep -qF '{{ es_api }}/_cat/master?format=json' <<<"${playbook}"
  grep -qF 'active_master_node: "{{ active_master_resp.json[0].node }}"' <<<"${playbook}"
  grep -qF 'ansible.builtin.meta: end_host' <<<"${playbook}"
  grep -qF 'inventory_hostname == active_master_node and ansible_play_hosts | length > 1' <<<"${playbook}"
}

@test "Kafka scaling changes and restarts ingestion only below the 16-partition boundary" {
  playbook="$(extract_playbook_yaml scale-kafka-partitions.yml)"

  grep -qF 'serial: 1' <<<"${playbook}"
  grep -qF "regex_search('PartitionCount:\\\\s*(\\\\d+)', '\\\\1')" <<<"${playbook}"
  [ "$(grep -c 'when: "current_partitions < 16"' <<<"${playbook}")" -eq 3 ]
  grep -qF -- '--alter --topic soc-events --partitions 16' <<<"${playbook}"
  grep -qF 'systemctl --user restart ingestion-stack.service' <<<"${playbook}"
  grep -qF 'port: 5044' <<<"${playbook}"

  run grep -F 'current_partitions != 16' <<<"${playbook}"
  [ "${status}" -eq 1 ]
}

@test "Fleet updates use bracket notation, POST requests, and conflict-safe status handling" {
  playbook="$(extract_playbook_yaml upgrade-fleet-integrations.yml)"

  grep -qF "installed_packages_resp.json['items']" <<<"${playbook}"
  grep -qF '/api/fleet/epm/packages/{{ item.name }}-{{ item.version }}' <<<"${playbook}"
  grep -qF 'method: POST' <<<"${playbook}"
  grep -qF 'status_code: [200, 409]' <<<"${playbook}"
  grep -qF "item.version != item.installed_version | default('')" <<<"${playbook}"

  run grep -F 'installed_packages_resp.json.items' <<<"${playbook}"
  [ "${status}" -eq 1 ]
}

@test "Semaphore backup avoids command-line passwords and verifies both backup artefacts" {
  playbook="$(extract_playbook_yaml backup-semaphore-podman.yml)"

  grep -qF 'mysqldump --defaults-extra-file=/var/lib/mysql/my.cnf' <<<"${playbook}"
  grep -qF 'no_log: true' <<<"${playbook}"
  grep -qF 'db_stat.stat.size < 5000' <<<"${playbook}"
  grep -qF 'podman stop semaphore-stack-semaphore-db' <<<"${playbook}"
  grep -qF 'podman start semaphore-stack-semaphore-db' <<<"${playbook}"
  grep -qF 'vol_stat.stat.size < 1000' <<<"${playbook}"

  run grep -E 'mysqldump[^[:cntrl:]]+-p(assword)?[^[:space:]]+' <<<"${playbook}"
  [ "${status}" -eq 1 ]
}

@test "ARA deployment pins the package and wires the YAML manifest into the Quadlet" {
  playbook="$(extract_playbook_yaml deploy-ara-podman.yml)"

  grep -qF 'ara_version: "1.8.0"' <<<"${playbook}"
  grep -qF 'ara=={{ ara_version }}' <<<"${playbook}"
  grep -qF 'dest: "{{ quadlet_dir }}/ara-stack.yaml"' <<<"${playbook}"
  grep -qF 'dest: "{{ quadlet_dir }}/ara-stack.kube"' <<<"${playbook}"
  grep -qF 'Yaml=/home/soc-admin/.config/containers/systemd/ara-stack.yaml' <<<"${playbook}"
  grep -qF 'failed_when: not ara_yaml_stat.stat.exists' <<<"${playbook}"
  grep -qF 'name: ara-stack.service' <<<"${playbook}"
}

@test "CLI verification examples require a CA and do not disable TLS or expose inline credentials" {
  cli_section="$(awk '/^### 6\.3 CLI Health Probe:/ { found = 1 } found { print } /^\*\*\*$/ && found { exit }' "${PLAYBOOK_DOC}")"

  [ "$(grep -c 'curl -s --cacert /etc/ssl/certs/ca-certificates.crt' <<<"${cli_section}")" -eq 3 ]

  run grep -E 'curl[^[:cntrl:]]+([[:space:]]-k([[:space:]]|$)|--insecure|[[:space:]]-u[[:space:]])' <<<"${cli_section}"
  [ "${status}" -eq 1 ]
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
