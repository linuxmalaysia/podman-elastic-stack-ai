#!/usr/bin/env bats
#
# Regression tests for PLAYBOOKS.md, the documentation introduced for the
# Ansible-based migration of the setup_*.sh bash scripts. These guard against
# the documentation drifting away from the actual files it describes
# (ansible/group_vars/all.yml, ansible/main.yml, the three setup_*.yml
# playbooks and run_playbooks.sh), following the same "docs must match code"
# philosophy as test-scripts/docs_content.bats.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
PLAYBOOKS_DOC="${REPO_ROOT}/PLAYBOOKS.md"
MAIN_PLAYBOOK="${REPO_ROOT}/ansible/main.yml"

@test "PLAYBOOKS.md exists and is readable" {
  [ -f "${PLAYBOOKS_DOC}" ]
  [ -r "${PLAYBOOKS_DOC}" ]
}

@test "PLAYBOOKS.md documents the target Elastic Stack version 9.4.4" {
  grep -qF '# Ansible Playbooks for Podman Elastic Stack 9.4.4' "${PLAYBOOKS_DOC}"
  grep -qF 'setting up Elastic Stack version **9.4.4** running locally in Podman 5+.' "${PLAYBOOKS_DOC}"
}

@test "PLAYBOOKS.md documents the ansible directory structure with all expected files" {
  grep -qF 'ansible/' "${PLAYBOOKS_DOC}"
  grep -qF 'group_vars/' "${PLAYBOOKS_DOC}"
  grep -qF '│   └── all.yml' "${PLAYBOOKS_DOC}"
  grep -qF 'main.yml' "${PLAYBOOKS_DOC}"
  grep -qF 'setup_elasticsearch.yml' "${PLAYBOOKS_DOC}"
  grep -qF 'setup_kibana.yml' "${PLAYBOOKS_DOC}"
  grep -qF 'setup_fleet_server.yml' "${PLAYBOOKS_DOC}"
}

@test "PLAYBOOKS.md describes group_vars/all.yml key variables" {
  grep -qF '`elk_version`: Set to `"9.4.4"` as required.' "${PLAYBOOKS_DOC}"
  grep -qF '`container_name`: Elasticsearch container name (`es01`).' "${PLAYBOOKS_DOC}"
  grep -qF '`data_dir`: Host data directory for Elasticsearch (`/data/es01`).' "${PLAYBOOKS_DOC}"
  grep -qF '`kibana_container_name`: Kibana container name (`kib01`).' "${PLAYBOOKS_DOC}"
}

@test "PLAYBOOKS.md describes the setup_elasticsearch.yml actions" {
  grep -qF 'Automates the installation of Elasticsearch.' "${PLAYBOOKS_DOC}"
  grep -qF 'Resets and retrieves the `elastic` user password, saving it to `elk-wolfi/temp_credentials.txt`.' "${PLAYBOOKS_DOC}"
  grep -qF 'Generates the Kibana enrollment token.' "${PLAYBOOKS_DOC}"
}

@test "PLAYBOOKS.md describes the setup_kibana.yml actions" {
  grep -qF 'Automates the installation and configuration of Kibana.' "${PLAYBOOKS_DOC}"
  grep -qF 'Retrieves the Kibana verification code using `podman exec`.' "${PLAYBOOKS_DOC}"
}

@test "PLAYBOOKS.md describes the setup_fleet_server.yml actions" {
  grep -qF 'Deploys and registers the Elastic Fleet Server agent.' "${PLAYBOOKS_DOC}"
  grep -qF 'Starts the Fleet Server container as the root user (or configured user).' "${PLAYBOOKS_DOC}"
}

@test "PLAYBOOKS.md documents run_playbooks.sh as the recommended entry point" {
  grep -qF 'chmod +x run_playbooks.sh' "${PLAYBOOKS_DOC}"
  grep -qF './run_playbooks.sh' "${PLAYBOOKS_DOC}"
}

@test "PLAYBOOKS.md documents how to run each playbook individually with ansible-playbook" {
  grep -qF 'ansible-playbook -i localhost, -c local ansible/setup_elasticsearch.yml' "${PLAYBOOKS_DOC}"
  grep -qF 'ansible-playbook -i localhost, -c local ansible/setup_kibana.yml' "${PLAYBOOKS_DOC}"
  grep -qF 'ansible-playbook -i localhost, -c local ansible/setup_fleet_server.yml' "${PLAYBOOKS_DOC}"
}

@test "PLAYBOOKS.md documents passing fleet_server_service_token and fleet_server_policy_id as extra vars" {
  grep -qF 'ansible-playbook -i localhost, -c local ansible/main.yml \' "${PLAYBOOKS_DOC}"
  grep -qF '-e "fleet_server_service_token=YOUR_TOKEN_HERE" \' "${PLAYBOOKS_DOC}"
  grep -qF '-e "fleet_server_policy_id=YOUR_POLICY_ID"' "${PLAYBOOKS_DOC}"
}

@test "PLAYBOOKS.md's documented import order for main.yml matches the actual ansible/main.yml order" {
  # Regression guard: the numbered list "1. setup_elasticsearch.yml,
  # 2. setup_kibana.yml, 3. setup_fleet_server.yml" must stay in sync with
  # the real import_playbook order in ansible/main.yml.
  local doc_es doc_kibana doc_fleet real_es real_kibana real_fleet

  doc_es="$(grep -n '1\. `setup_elasticsearch.yml`' "${PLAYBOOKS_DOC}" | head -n1 | cut -d: -f1)"
  doc_kibana="$(grep -n '2\. `setup_kibana.yml`' "${PLAYBOOKS_DOC}" | head -n1 | cut -d: -f1)"
  doc_fleet="$(grep -n '3\. `setup_fleet_server.yml`' "${PLAYBOOKS_DOC}" | head -n1 | cut -d: -f1)"

  [ -n "${doc_es}" ]
  [ -n "${doc_kibana}" ]
  [ -n "${doc_fleet}" ]
  [ "${doc_es}" -lt "${doc_kibana}" ]
  [ "${doc_kibana}" -lt "${doc_fleet}" ]

  real_es="$(grep -n 'import_playbook: setup_elasticsearch.yml' "${MAIN_PLAYBOOK}" | head -n1 | cut -d: -f1)"
  real_kibana="$(grep -n 'import_playbook: setup_kibana.yml' "${MAIN_PLAYBOOK}" | head -n1 | cut -d: -f1)"
  real_fleet="$(grep -n 'import_playbook: setup_fleet_server.yml' "${MAIN_PLAYBOOK}" | head -n1 | cut -d: -f1)"

  [ -n "${real_es}" ]
  [ -n "${real_kibana}" ]
  [ -n "${real_fleet}" ]
  [ "${real_es}" -lt "${real_kibana}" ]
  [ "${real_kibana}" -lt "${real_fleet}" ]
}