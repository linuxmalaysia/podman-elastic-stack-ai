#!/usr/bin/env bats
#
# Structural/content regression tests for the Ansible playbooks introduced to
# migrate the setup_*.sh bash scripts to Ansible:
#   ansible/group_vars/all.yml
#   ansible/main.yml
#   ansible/setup_elasticsearch.yml
#   ansible/setup_kibana.yml
#   ansible/setup_fleet_server.yml
#
# ansible-playbook is not assumed to be installed in the test environment, so
# these tests do not execute the playbooks. Instead, following the same
# philosophy as test-scripts/setup_step1_install.bats (which extracts and
# inspects script text rather than running real podman/apt commands), they
# assert on the exact task names, variables, and command strings that the
# playbooks are documented (PLAYBOOKS.md) to perform. This guards against
# accidental drift or breakage in the YAML content.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ANSIBLE_DIR="${REPO_ROOT}/ansible"

GROUP_VARS="${ANSIBLE_DIR}/group_vars/all.yml"
MAIN_PLAYBOOK="${ANSIBLE_DIR}/main.yml"
ES_PLAYBOOK="${ANSIBLE_DIR}/setup_elasticsearch.yml"
KIBANA_PLAYBOOK="${ANSIBLE_DIR}/setup_kibana.yml"
FLEET_PLAYBOOK="${ANSIBLE_DIR}/setup_fleet_server.yml"

# Returns the 1-based line number of the first line containing the given
# fixed string in the given file, or empty if not found.
_first_line_of() {
  local needle="$1"
  local file="$2"
  grep -nF -- "${needle}" "${file}" | head -n1 | cut -d: -f1
}

# ---------------------------------------------------------------------------
# File presence / basic YAML sanity
# ---------------------------------------------------------------------------

@test "ansible/group_vars/all.yml exists, is readable and starts with a YAML document marker" {
  [ -f "${GROUP_VARS}" ]
  [ -r "${GROUP_VARS}" ]
  [ "$(head -n1 "${GROUP_VARS}")" = "---" ]
}

@test "ansible/main.yml exists, is readable and starts with a YAML document marker" {
  [ -f "${MAIN_PLAYBOOK}" ]
  [ -r "${MAIN_PLAYBOOK}" ]
  [ "$(head -n1 "${MAIN_PLAYBOOK}")" = "---" ]
}

@test "ansible/setup_elasticsearch.yml exists, is readable and starts with a YAML document marker" {
  [ -f "${ES_PLAYBOOK}" ]
  [ -r "${ES_PLAYBOOK}" ]
  [ "$(head -n1 "${ES_PLAYBOOK}")" = "---" ]
}

@test "ansible/setup_kibana.yml exists, is readable and starts with a YAML document marker" {
  [ -f "${KIBANA_PLAYBOOK}" ]
  [ -r "${KIBANA_PLAYBOOK}" ]
  [ "$(head -n1 "${KIBANA_PLAYBOOK}")" = "---" ]
}

@test "ansible/setup_fleet_server.yml exists, is readable and starts with a YAML document marker" {
  [ -f "${FLEET_PLAYBOOK}" ]
  [ -r "${FLEET_PLAYBOOK}" ]
  [ "$(head -n1 "${FLEET_PLAYBOOK}")" = "---" ]
}

@test "ansible playbook YAML files do not contain literal tab characters" {
  local tab
  tab="$(printf '\t')"
  for f in "${GROUP_VARS}" "${MAIN_PLAYBOOK}" "${ES_PLAYBOOK}" "${KIBANA_PLAYBOOK}" "${FLEET_PLAYBOOK}"; do
    run grep -qF "${tab}" "${f}"
    [ "${status}" -ne 0 ]
  done
}

# ---------------------------------------------------------------------------
# ansible/group_vars/all.yml
# ---------------------------------------------------------------------------

@test "group_vars/all.yml pins elk_version to 9.4.4" {
  grep -qF 'elk_version: "9.4.4"' "${GROUP_VARS}"
}

@test "group_vars/all.yml derives elk_base_dir from the playbook directory's parent" {
  grep -qF 'elk_base_dir: "{{ playbook_dir | dirname }}"' "${GROUP_VARS}"
}

@test "group_vars/all.yml derives elk_dir and cert_dir relative to elk_base_dir" {
  grep -qF 'elk_dir: "{{ elk_base_dir }}/elk-wolfi"' "${GROUP_VARS}"
  grep -qF 'cert_dir: "{{ elk_dir }}/certs"' "${GROUP_VARS}"
}

@test "group_vars/all.yml defines the elasticsearch container name and data directory" {
  grep -qF 'container_name: "es01"' "${GROUP_VARS}"
  grep -qF 'data_dir: "/data/{{ container_name }}"' "${GROUP_VARS}"
}

@test "group_vars/all.yml pins the elasticsearch wolfi image to elk_version" {
  grep -qF 'elasticsearch_image: "docker.elastic.co/elasticsearch/elasticsearch-wolfi:{{ elk_version }}"' "${GROUP_VARS}"
}

@test "group_vars/all.yml defines the kibana image name, container name and port" {
  grep -qF 'kibana_image_name: "docker.elastic.co/kibana/kibana-wolfi"' "${GROUP_VARS}"
  grep -qF 'kibana_container_name: "kib01"' "${GROUP_VARS}"
  grep -qF 'kibana_port: "5601"' "${GROUP_VARS}"
}

@test "group_vars/all.yml defines the shared podman network name" {
  grep -qF 'network_name: "elk-wolfi_elastic"' "${GROUP_VARS}"
}

@test "group_vars/all.yml defines the temp credentials file path under elk_dir" {
  grep -qF 'temp_credentials_file: "{{ elk_dir }}/temp_credentials.txt"' "${GROUP_VARS}"
}

@test "group_vars/all.yml defines the fleet server image, container name and port" {
  grep -qF 'fleet_server_image_name: "docker.elastic.co/elastic-agent/elastic-agent-complete-wolfi"' "${GROUP_VARS}"
  grep -qF 'fleet_server_container_name: "fleet-server"' "${GROUP_VARS}"
  grep -qF 'fleet_server_port: "8220"' "${GROUP_VARS}"
}

@test "group_vars/all.yml defaults fleet_server_service_token and fleet_server_policy_id to empty strings so -e can override them" {
  grep -qF 'fleet_server_service_token: ""' "${GROUP_VARS}"
  grep -qF 'fleet_server_policy_id: ""' "${GROUP_VARS}"
  grep -qF -- "-e \"fleet_server_service_token=XYZ\"" "${GROUP_VARS}"
}

# ---------------------------------------------------------------------------
# ansible/main.yml
# ---------------------------------------------------------------------------

@test "main.yml imports the elasticsearch, kibana and fleet server playbooks" {
  grep -qF 'import_playbook: setup_elasticsearch.yml' "${MAIN_PLAYBOOK}"
  grep -qF 'import_playbook: setup_kibana.yml' "${MAIN_PLAYBOOK}"
  grep -qF 'import_playbook: setup_fleet_server.yml' "${MAIN_PLAYBOOK}"
}

@test "main.yml uses import_playbook (static, ordered import) rather than include_playbook" {
  run grep -qF 'include_playbook' "${MAIN_PLAYBOOK}"
  [ "${status}" -ne 0 ]
}

@test "main.yml imports the playbooks in the documented order: elasticsearch, then kibana, then fleet server" {
  local es_line kibana_line fleet_line
  es_line="$(_first_line_of 'import_playbook: setup_elasticsearch.yml' "${MAIN_PLAYBOOK}")"
  kibana_line="$(_first_line_of 'import_playbook: setup_kibana.yml' "${MAIN_PLAYBOOK}")"
  fleet_line="$(_first_line_of 'import_playbook: setup_fleet_server.yml' "${MAIN_PLAYBOOK}")"

  [ -n "${es_line}" ]
  [ -n "${kibana_line}" ]
  [ -n "${fleet_line}" ]
  [ "${es_line}" -lt "${kibana_line}" ]
  [ "${kibana_line}" -lt "${fleet_line}" ]
}

# ---------------------------------------------------------------------------
# ansible/setup_elasticsearch.yml
# ---------------------------------------------------------------------------

@test "setup_elasticsearch.yml targets localhost with a local connection" {
  grep -qF 'hosts: localhost' "${ES_PLAYBOOK}"
  grep -qF 'connection: local' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml explicitly loads group_vars/all.yml via include_vars" {
  grep -qF 'include_vars:' "${ES_PLAYBOOK}"
  grep -qF 'file: group_vars/all.yml' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml Step 1 checks for both podman and podman-compose before installing" {
  grep -qF 'command: which {{ item }}' "${ES_PLAYBOOK}"
  grep -qF '- podman' "${ES_PLAYBOOK}"
  grep -qF '- podman-compose' "${ES_PLAYBOOK}"
  grep -qF "commands_missing: \"{{ commands_check.results | selectattr('rc', 'ne', 0) | list | length > 0 }}\"" "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml installs podman and podman-compose via apt only on Debian-family hosts" {
  grep -qF "ansible_os_family == 'Debian'" "${ES_PLAYBOOK}"
  grep -qF 'Install podman and podman-compose via apt' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml installs epel-release and podman/podman-compose via dnf on RedHat-family hosts" {
  grep -qF "ansible_os_family == 'RedHat'" "${ES_PLAYBOOK}"
  grep -qF 'Install EPEL release via dnf' "${ES_PLAYBOOK}"
  grep -qF 'Install podman and podman-compose via dnf' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml Step 2 aborts installation when the data directory already exists" {
  grep -qF "Data directory '{{ data_dir }}' already exists" "${ES_PLAYBOOK}"
  grep -qF 'when: data_dir_stat.stat.exists and data_dir_stat.stat.isdir' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml Step 2 creates the data directory owned by uid/gid 1000" {
  grep -qF 'owner: "1000"' "${ES_PLAYBOOK}"
  grep -qF 'group: "1000"' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml Step 3 pulls the configured elasticsearch image" {
  grep -qF 'command: podman pull "{{ elasticsearch_image }}"' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml Step 4 only verifies the image signature with cosign when cosign is installed" {
  grep -qF 'command: which cosign' "${ES_PLAYBOOK}"
  grep -qF 'when: cosign_check.rc == 0' "${ES_PLAYBOOK}"
  grep -qF 'cosign verify --key /tmp/cosign.pub "{{ elasticsearch_image }}"' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml Step 5 generates a podman-compose.yml exposing port 9200 with single-node discovery" {
  grep -qF 'image: {{ elasticsearch_image }}' "${ES_PLAYBOOK}"
  grep -qF 'container_name: {{ container_name }}' "${ES_PLAYBOOK}"
  grep -qF '"9200:9200"' "${ES_PLAYBOOK}"
  grep -qF 'discovery.type=single-node' "${ES_PLAYBOOK}"
  grep -qF 'dest: "{{ elk_dir }}/podman-compose.yml"' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml Step 5 mounts the data directory into the elasticsearch data path" {
  grep -qF '"{{ data_dir }}:/usr/share/elasticsearch/data"' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml Step 6 resets the elastic user password and extracts the new value" {
  grep -qF 'elasticsearch-reset-password -u elastic -a -f -b' "${ES_PLAYBOOK}"
  grep -qF "grep -oP 'New value: \\\\K.*'" "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml Step 6 persists the elastic password to the temp credentials file" {
  grep -qF 'line: "Elastic password set to: {{ elastic_password }}"' "${ES_PLAYBOOK}"
  grep -qF 'path: "{{ temp_credentials_file }}"' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml Step 7 recreates the certificate directory before copying http_ca.crt" {
  grep -qF 'path: "{{ cert_dir }}"' "${ES_PLAYBOOK}"
  grep -qF '- absent' "${ES_PLAYBOOK}"
  grep -qF '- directory' "${ES_PLAYBOOK}"
  grep -qF 'podman cp {{ container_name }}:/usr/share/elasticsearch/config/certs/http_ca.crt {{ cert_dir }}/http_ca.crt' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml Step 8 verifies connectivity with both header-based and basic-auth curl calls" {
  grep -qF 'Authorization: Basic' "${ES_PLAYBOOK}"
  grep -qF 'b64encode' "${ES_PLAYBOOK}"
  grep -qF 'curl --cacert {{ cert_dir }}/http_ca.crt -H' "${ES_PLAYBOOK}"
  grep -qF 'command: curl --cacert {{ cert_dir }}/http_ca.crt -u "elastic:{{ elastic_password }}" https://localhost:9200' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml Step 9 creates and persists the kibana enrollment token" {
  grep -qF 'elasticsearch-create-enrollment-token -s kibana' "${ES_PLAYBOOK}"
  grep -qF 'line: "Kibana enrollment token: {{ parsed_token.stdout | trim }}"' "${ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml numbers its steps in ascending order" {
  local s1 s2 s3 s4 s5 s6 s7 s8 s9
  s1="$(_first_line_of 'Step 1 - Check and Install Podman and Podman Compose' "${ES_PLAYBOOK}")"
  s2="$(_first_line_of 'Step 2 - Create Data Directory' "${ES_PLAYBOOK}")"
  s3="$(_first_line_of 'Step 3 - Pull Elasticsearch Docker Image' "${ES_PLAYBOOK}")"
  s4="$(_first_line_of 'Step 4 - Optional: Install and Verify Cosign' "${ES_PLAYBOOK}")"
  s5="$(_first_line_of 'Step 5 - Start Elasticsearch Container using podman-compose' "${ES_PLAYBOOK}")"
  s6="$(_first_line_of 'Step 6 - Retrieve and Store Elasticsearch Password' "${ES_PLAYBOOK}")"
  s7="$(_first_line_of 'Step 7 - Copy SSL Certificate' "${ES_PLAYBOOK}")"
  s8="$(_first_line_of 'Step 8 - Make REST API Call' "${ES_PLAYBOOK}")"
  s9="$(_first_line_of 'Step 9 - Retrieve and Clean Kibana Enrollment Token' "${ES_PLAYBOOK}")"

  for n in s1 s2 s3 s4 s5 s6 s7 s8 s9; do
    [ -n "${!n}" ]
  done
  [ "${s1}" -lt "${s2}" ]
  [ "${s2}" -lt "${s3}" ]
  [ "${s3}" -lt "${s4}" ]
  [ "${s4}" -lt "${s5}" ]
  [ "${s5}" -lt "${s6}" ]
  [ "${s6}" -lt "${s7}" ]
  [ "${s7}" -lt "${s8}" ]
  [ "${s8}" -lt "${s9}" ]
}

@test "setup_elasticsearch.yml elevates privileges only for package installation and data directory creation" {
  # Regression guard: exactly the 5 privileged tasks (apt update, apt install,
  # dnf epel install, dnf package install, data dir creation) should use
  # become: true. If this count changes, it signals a privilege-scope change
  # that should be reviewed deliberately.
  count="$(grep -cF 'become: true' "${ES_PLAYBOOK}")"
  [ "${count}" -eq 5 ]
}

# ---------------------------------------------------------------------------
# ansible/setup_kibana.yml
# ---------------------------------------------------------------------------

@test "setup_kibana.yml targets localhost with a local connection" {
  grep -qF 'hosts: localhost' "${KIBANA_PLAYBOOK}"
  grep -qF 'connection: local' "${KIBANA_PLAYBOOK}"
}

@test "setup_kibana.yml fails fast when podman or podman-compose are missing" {
  grep -qF 'Error: Podman or podman-compose is not installed. Please run setup_elasticsearch.yml first.' "${KIBANA_PLAYBOOK}"
  grep -qF 'when: podman_check.rc != 0 or compose_check.rc != 0' "${KIBANA_PLAYBOOK}"
}

@test "setup_kibana.yml fails fast when the elasticsearch certificate is missing" {
  grep -qF "Error: Elasticsearch certificate file not found at '{{ cert_dir }}/http_ca.crt'. Please run setup_elasticsearch.yml successfully." "${KIBANA_PLAYBOOK}"
  grep -qF 'when: not cert_stat.stat.exists' "${KIBANA_PLAYBOOK}"
}

@test "setup_kibana.yml fails fast when the elasticsearch podman network is missing" {
  grep -qF "Error: The Podman network '{{ network_name }}' does not exist. Please run setup_elasticsearch.yml successfully." "${KIBANA_PLAYBOOK}"
  grep -qF 'when: network_check.rc != 0' "${KIBANA_PLAYBOOK}"
}

@test "setup_kibana.yml fails fast when the temp credentials file or the elastic password are missing" {
  grep -qF "Error: Temporary credentials file '{{ temp_credentials_file }}' not found." "${KIBANA_PLAYBOOK}"
  grep -qF "Error: Elasticsearch password not found in '{{ temp_credentials_file }}'." "${KIBANA_PLAYBOOK}"
  grep -qF 'when: elastic_password | length == 0' "${KIBANA_PLAYBOOK}"
}

@test "setup_kibana.yml verifies elasticsearch is reachable before proceeding" {
  grep -qF "'You Know, for Search' not in es_status_out.stdout" "${KIBANA_PLAYBOOK}"
  grep -qF 'Error: Elasticsearch is not running or status check failed.' "${KIBANA_PLAYBOOK}"
}

@test "setup_kibana.yml derives the kibana image tag from the detected elasticsearch version" {
  grep -qF '(es_status_out.stdout | from_json).version.number' "${KIBANA_PLAYBOOK}"
  grep -qF 'kibana_image: "{{ kibana_image_name }}:{{ elasticsearch_version }}"' "${KIBANA_PLAYBOOK}"
}

@test "setup_kibana.yml extracts the default kibana.yml from a disposable temporary container" {
  grep -qF 'temp_kibana_container: "temp_kib01"' "${KIBANA_PLAYBOOK}"
  grep -qF 'podman cp "{{ temp_kibana_container }}:/usr/share/kibana/config/kibana.yml" "{{ elk_dir }}/kibana.yml"' "${KIBANA_PLAYBOOK}"
  grep -qF 'Stop and remove temporary container' "${KIBANA_PLAYBOOK}"
}

@test "setup_kibana.yml generates a podman-compose file that mounts the custom kibana.yml and exposes kibana_port" {
  grep -qF './kibana.yml:/usr/share/kibana/config/kibana.yml' "${KIBANA_PLAYBOOK}"
  grep -qF '"{{ kibana_port }}:{{ kibana_port }}"' "${KIBANA_PLAYBOOK}"
  grep -qF 'dest: "{{ elk_dir }}/podman-compose-kibana.yml"' "${KIBANA_PLAYBOOK}"
  grep -qF 'external: true' "${KIBANA_PLAYBOOK}"
}

@test "setup_kibana.yml retrieves the kibana enrollment token and verification code" {
  grep -qF 'elasticsearch-create-enrollment-token -s kibana' "${KIBANA_PLAYBOOK}"
  grep -qF 'kibana-verification-code' "${KIBANA_PLAYBOOK}"
}

@test "setup_kibana.yml updates the existing enrollment token line rather than duplicating it" {
  grep -qF 'regexp: "^Kibana enrollment token:"' "${KIBANA_PLAYBOOK}"
  grep -qF 'line: "Kibana enrollment token: {{ kibana_enrollment_token }}"' "${KIBANA_PLAYBOOK}"
}

@test "setup_kibana.yml does not elevate privileges (no become: true tasks)" {
  run grep -qF 'become: true' "${KIBANA_PLAYBOOK}"
  [ "${status}" -ne 0 ]
}

# ---------------------------------------------------------------------------
# ansible/setup_fleet_server.yml
# ---------------------------------------------------------------------------

@test "setup_fleet_server.yml targets localhost with a local connection" {
  grep -qF 'hosts: localhost' "${FLEET_PLAYBOOK}"
  grep -qF 'connection: local' "${FLEET_PLAYBOOK}"
}

@test "setup_fleet_server.yml fails fast when podman, the certificate, or the network are missing" {
  grep -qF 'Error: Podman or podman-compose is not installed.' "${FLEET_PLAYBOOK}"
  grep -qF "Error: Elasticsearch certificate file not found at '{{ cert_dir }}/http_ca.crt'." "${FLEET_PLAYBOOK}"
  grep -qF "Error: The Podman network '{{ network_name }}' does not exist." "${FLEET_PLAYBOOK}"
}

@test "setup_fleet_server.yml derives the fleet server image tag from the detected elasticsearch version" {
  grep -qF 'fleet_server_image: "{{ fleet_server_image_name }}:{{ elasticsearch_version }}"' "${FLEET_PLAYBOOK}"
  grep -qF 'command: podman pull "{{ fleet_server_image }}"' "${FLEET_PLAYBOOK}"
}

@test "setup_fleet_server.yml resolves the elasticsearch container name via podman inspect" {
  grep -qF 'command: podman inspect es01' "${FLEET_PLAYBOOK}"
  grep -qF "es_container_name: \"{{ (es_inspect.stdout | from_json)[0].Name | regex_replace('^/', '') }}\"" "${FLEET_PLAYBOOK}"
}

@test "setup_fleet_server.yml prompts for the service token and policy ID only when not already provided" {
  grep -qF 'when: fleet_server_service_token | length == 0' "${FLEET_PLAYBOOK}"
  grep -qF 'when: fleet_server_policy_id | length == 0' "${FLEET_PLAYBOOK}"
  grep -qF 'prompt: "Enter the Fleet Service Token (generated from Fleet policy in Kibana):"' "${FLEET_PLAYBOOK}"
  grep -qF 'prompt: "Enter the Fleet Server Policy ID:"' "${FLEET_PLAYBOOK}"
}

@test "setup_fleet_server.yml fails when the resolved token or policy ID are still empty" {
  grep -qF 'Error: Fleet Service Token and Fleet Server Policy ID are both required.' "${FLEET_PLAYBOOK}"
  grep -qF 'when: (resolved_fleet_token | length == 0) or (resolved_policy_id | length == 0)' "${FLEET_PLAYBOOK}"
}

@test "setup_fleet_server.yml generates a podman-compose file wiring the resolved service token and policy ID" {
  grep -qF 'FLEET_SERVER_SERVICE_TOKEN={{ resolved_fleet_token }}' "${FLEET_PLAYBOOK}"
  grep -qF 'FLEET_SERVER_POLICY_ID={{ resolved_policy_id }}' "${FLEET_PLAYBOOK}"
  grep -qF 'FLEET_SERVER_ELASTICSEARCH_HOST=https://{{ es_container_name }}:9200' "${FLEET_PLAYBOOK}"
  grep -qF 'dest: "{{ elk_dir }}/podman-compose-fleet-server.yml"' "${FLEET_PLAYBOOK}"
}

@test "setup_fleet_server.yml runs the container as root and warns about switching to elastic-agent" {
  grep -qF 'user: root' "${FLEET_PLAYBOOK}"
  grep -qF "you should change the 'user' parameter" "${FLEET_PLAYBOOK}"
  grep -qF "from 'root' to 'elastic-agent'" "${FLEET_PLAYBOOK}"
}

@test "setup_fleet_server.yml does not elevate privileges (no become: true tasks)" {
  run grep -qF 'become: true' "${FLEET_PLAYBOOK}"
  [ "${status}" -ne 0 ]
}