#!/usr/bin/env bats
#
# Regression tests for the WSL2 3-Node Elasticsearch + Kibana cluster support
# introduced across site.yml, ansible/group_vars/all.yml,
# ansible/setup_elasticsearch.yml, ansible/setup_kibana.yml and
# inventory/hosts.wsl.3node.yml. These guard against the deployment_option
# == 'wsl2' branches (multi-node compose templates, per-node data dirs,
# static credentials, and Kibana multi-host wiring) being accidentally
# broken, removed, or merged back into the single-node code path.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SITE_YML="${REPO_ROOT}/site.yml"
MAIN_PLAYBOOK="${REPO_ROOT}/ansible/main.yml"
GROUP_VARS="${REPO_ROOT}/ansible/group_vars/all.yml"
SETUP_ES="${REPO_ROOT}/ansible/setup_elasticsearch.yml"
SETUP_KIBANA="${REPO_ROOT}/ansible/setup_kibana.yml"
INVENTORY="${REPO_ROOT}/inventory/hosts.wsl.3node.yml"

# --- site.yml -----------------------------------------------------------

@test "site.yml exists and is readable" {
  [ -f "${SITE_YML}" ]
  [ -r "${SITE_YML}" ]
}

@test "site.yml is a valid playbook document that imports ansible/main.yml" {
  run head -n 1 "${SITE_YML}"
  [ "${output}" = "---" ]

  grep -qF -- '- import_playbook: ansible/main.yml' "${SITE_YML}"
}

@test "site.yml does not contain tab characters" {
  run grep -q "$(printf '\t')" "${SITE_YML}"
  [ "${status}" -ne 0 ]
}

@test "site.yml references a playbook that actually exists in the repo" {
  [ -f "${MAIN_PLAYBOOK}" ]
}

# --- ansible/group_vars/all.yml ------------------------------------------

@test "ansible/group_vars/all.yml exists and is readable" {
  [ -f "${GROUP_VARS}" ]
  [ -r "${GROUP_VARS}" ]
}

@test "group_vars/all.yml derives container_name from deployment_option for wsl2" {
  grep -qF "container_name: \"{{ 'dsom-persistence-es-node-01' if (deployment_option == 'wsl2') else 'es01' }}\"" "${GROUP_VARS}"
}

@test "group_vars/all.yml derives kibana_container_name from deployment_option for wsl2" {
  grep -qF "kibana_container_name: \"{{ 'dsom-kibana-kibana-local' if (deployment_option == 'wsl2') else 'kib01' }}\"" "${GROUP_VARS}"
}

@test "group_vars/all.yml preserves the single-node fallback container names" {
  # Regression guard: the wsl2 conditional must not drop the original
  # single-node container names used when deployment_option != 'wsl2'.
  grep -qF "else 'es01'" "${GROUP_VARS}"
  grep -qF "else 'kib01'" "${GROUP_VARS}"
}

@test "group_vars/all.yml data_dir still derives from container_name" {
  grep -qF 'data_dir: "/data/{{ container_name }}"' "${GROUP_VARS}"
}

# --- ansible/setup_elasticsearch.yml -------------------------------------

@test "ansible/setup_elasticsearch.yml exists and is readable" {
  [ -f "${SETUP_ES}" ]
  [ -r "${SETUP_ES}" ]
}

@test "setup_elasticsearch.yml guards single-node data directory creation so it is skipped for wsl2" {
  run grep -A 11 "Create data directories (Single Node)" "${SETUP_ES}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"when: deployment_option != 'wsl2'"* ]]
}

@test "setup_elasticsearch.yml creates per-node data directories for the WSL 3-node cluster" {
  grep -qF "Create data directories (WSL 3-Node Cluster)" "${SETUP_ES}"
  grep -qF "/opt/dsom-persistence" "${SETUP_ES}"
  grep -qF "/opt/dsom-persistence/data/es-node-01" "${SETUP_ES}"
  grep -qF "/opt/dsom-persistence/data/es-node-02" "${SETUP_ES}"
  grep -qF "/opt/dsom-persistence/data/es-node-03" "${SETUP_ES}"
}

@test "setup_elasticsearch.yml only runs the WSL data directory task when deployment_option is wsl2" {
  run grep -A 15 "Create data directories (WSL 3-Node Cluster)" "${SETUP_ES}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"when: deployment_option == 'wsl2'"* ]]
}

@test "setup_elasticsearch.yml defines separate podman-compose templates for single-node and WSL cluster" {
  grep -qF "Create podman-compose.yml for Elasticsearch (Single Node)" "${SETUP_ES}"
  grep -qF "Create podman-compose.yml for Elasticsearch (WSL 3-Node Cluster)" "${SETUP_ES}"
}

@test "setup_elasticsearch.yml WSL compose template names all three cluster nodes" {
  grep -qF "container_name: dsom-persistence-es-node-01" "${SETUP_ES}"
  grep -qF "container_name: dsom-persistence-es-node-02" "${SETUP_ES}"
  grep -qF "container_name: dsom-persistence-es-node-03" "${SETUP_ES}"
  grep -qF "cluster.name=dsom-wsl-cluster" "${SETUP_ES}"
  grep -qF "cluster.initial_master_nodes=es-node-01,es-node-02,es-node-03" "${SETUP_ES}"
}

@test "setup_elasticsearch.yml WSL compose template gives each node a distinct discovery seed list" {
  # Each node should seed off its two peers, never off itself.
  grep -qF "discovery.seed_hosts=es-node-02,es-node-03" "${SETUP_ES}"
  grep -qF "discovery.seed_hosts=es-node-01,es-node-03" "${SETUP_ES}"
  grep -qF "discovery.seed_hosts=es-node-01,es-node-02" "${SETUP_ES}"
}

@test "setup_elasticsearch.yml WSL compose template maps distinct host ports per node" {
  grep -qF '9200:9200' "${SETUP_ES}"
  grep -qF '9300:9300' "${SETUP_ES}"
  grep -qF '9201:9200' "${SETUP_ES}"
  grep -qF '9301:9300' "${SETUP_ES}"
  grep -qF '9202:9200' "${SETUP_ES}"
  grep -qF '9302:9300' "${SETUP_ES}"
}

@test "setup_elasticsearch.yml WSL compose template mounts each node's dedicated data directory" {
  grep -qF '/opt/dsom-persistence/data/es-node-01:/usr/share/elasticsearch/data' "${SETUP_ES}"
  grep -qF '/opt/dsom-persistence/data/es-node-02:/usr/share/elasticsearch/data' "${SETUP_ES}"
  grep -qF '/opt/dsom-persistence/data/es-node-03:/usr/share/elasticsearch/data' "${SETUP_ES}"
}

@test "setup_elasticsearch.yml sets a static elastic password for the wsl2 deployment option" {
  grep -qF "Set static password for WSL2 deployment option" "${SETUP_ES}"
  grep -qF 'elastic_password: "elastic"' "${SETUP_ES}"
  grep -qF 'password_reset_needed: false' "${SETUP_ES}"
}

@test "setup_elasticsearch.yml pre-populates the temp credentials file with the static wsl2 password" {
  grep -qF "Initialize temporary credentials file (WSL2)" "${SETUP_ES}"
  grep -qF 'Elastic password set to: elastic' "${SETUP_ES}"
}

@test "setup_elasticsearch.yml skips the interactive password-reset workflow for wsl2 deployments" {
  # Regression guard: the elasticsearch-reset-password command chain must
  # remain gated behind deployment_option != 'wsl2' now that wsl2 uses a
  # static password.
  run grep -A 6 "Reset elastic user password if needed" "${SETUP_ES}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"deployment_option != 'wsl2'"* ]]
}

@test "setup_elasticsearch.yml copies the CA certificate from the correct path per deployment option" {
  grep -qF "Copy http_ca.crt from container (Single Node)" "${SETUP_ES}"
  grep -qF "config/certs/http_ca.crt {{ cert_dir }}/http_ca.crt" "${SETUP_ES}"
  grep -qF "Copy http_ca.crt from container (WSL 3-Node Cluster)" "${SETUP_ES}"
  grep -qF "config/certs/ca/ca.crt {{ cert_dir }}/http_ca.crt" "${SETUP_ES}"
}

@test "setup_elasticsearch.yml gates the two http_ca.crt copy tasks on opposite deployment_option branches" {
  run grep -A 2 "Copy http_ca.crt from container (Single Node)" "${SETUP_ES}"
  [[ "${output}" == *"when: deployment_option != 'wsl2'"* ]]

  run grep -A 2 "Copy http_ca.crt from container (WSL 3-Node Cluster)" "${SETUP_ES}"
  [[ "${output}" == *"when: deployment_option == 'wsl2'"* ]]
}

# --- ansible/setup_kibana.yml ---------------------------------------------

@test "ansible/setup_kibana.yml exists and is readable" {
  [ -f "${SETUP_KIBANA}" ]
  [ -r "${SETUP_KIBANA}" ]
}

@test "setup_kibana.yml configures multi-host elasticsearch.hosts for the wsl2 3-node cluster" {
  grep -qF "Configure kibana.yml for WSL2 3-Node Cluster" "${SETUP_KIBANA}"
  grep -qF 'elasticsearch.hosts: ["https://dsom-persistence-es-node-01:9200", "https://dsom-persistence-es-node-02:9200", "https://dsom-persistence-es-node-03:9200"]' "${SETUP_KIBANA}"
}

@test "setup_kibana.yml wsl2 block only applies when deployment_option is wsl2" {
  run grep -A 9 "Configure kibana.yml for WSL2 3-Node Cluster" "${SETUP_KIBANA}"
  [[ "${output}" == *"when: deployment_option == 'wsl2'"* ]]
}

@test "setup_kibana.yml wsl2 block enables certificate-based SSL verification against the shared CA" {
  grep -qF 'elasticsearch.ssl.verificationMode: "certificate"' "${SETUP_KIBANA}"
  grep -qF 'elasticsearch.ssl.certificateAuthorities: ["/usr/share/kibana/config/certs/http_ca.crt"]' "${SETUP_KIBANA}"
}

@test "setup_kibana.yml mounts the shared certs directory into the Kibana container" {
  grep -qF './certs:/usr/share/kibana/config/certs' "${SETUP_KIBANA}"
}

# --- inventory/hosts.wsl.3node.yml ----------------------------------------

@test "inventory/hosts.wsl.3node.yml exists and is readable" {
  [ -f "${INVENTORY}" ]
  [ -r "${INVENTORY}" ]
}

@test "inventory/hosts.wsl.3node.yml does not contain tab characters" {
  run grep -q "$(printf '\t')" "${INVENTORY}"
  [ "${status}" -ne 0 ]
}

@test "inventory/hosts.wsl.3node.yml runs against localhost with a local connection" {
  grep -qF 'ansible_connection: local' "${INVENTORY}"
  grep -qF 'target_hosts: "localhost"' "${INVENTORY}"
}

@test "inventory/hosts.wsl.3node.yml uses placeholder ansible_user and dsom_group values" {
  grep -qF 'ansible_user: "your_username"' "${INVENTORY}"
  grep -qF 'dsom_group: "your_username"' "${INVENTORY}"
}

@test "inventory/hosts.wsl.3node.yml defines cluster metadata matching the WSL guide" {
  grep -qF 'cluster_name: "dsom-wsl-cluster"' "${INVENTORY}"
  grep -qF 'storage_base: "/opt/dsom-persistence/data"' "${INVENTORY}"
  grep -qF 'kibana_port: 5601' "${INVENTORY}"
}

@test "inventory/hosts.wsl.3node.yml declares exactly three cluster nodes" {
  run grep -c '^      - name: "es-node-' "${INVENTORY}"
  [ "${status}" -eq 0 ]
  [ "${output}" -eq 3 ]
}

@test "inventory/hosts.wsl.3node.yml assigns each node a unique http_port and transport_port pair" {
  grep -qF 'name: "es-node-01"' "${INVENTORY}"
  grep -qF 'name: "es-node-02"' "${INVENTORY}"
  grep -qF 'name: "es-node-03"' "${INVENTORY}"
  grep -qF 'http_port: 9200' "${INVENTORY}"
  grep -qF 'transport_port: 9300' "${INVENTORY}"
  grep -qF 'http_port: 9201' "${INVENTORY}"
  grep -qF 'transport_port: 9301' "${INVENTORY}"
  grep -qF 'http_port: 9202' "${INVENTORY}"
  grep -qF 'transport_port: 9302' "${INVENTORY}"
}