# Ansible Playbooks for Podman Elastic Stack 9.4.4

This document lists all the playbooks created to migrate the setup bash scripts to Ansible. The playbooks automate setting up Elastic Stack version **9.4.4** running locally in Podman 5+.

## Directory Structure

```text
ansible/
├── group_vars/
│   └── all.yml               # Common variables for all playbooks
├── main.yml                  # Primary playbook importing all individual playbooks
├── setup_elasticsearch.yml   # Ansible playbook to set up Elasticsearch
├── setup_kibana.yml          # Ansible playbook to set up Kibana
└── setup_fleet_server.yml    # Ansible playbook to set up Fleet Server
```

---

## Playbook Directory and Listing

### 1. `ansible/group_vars/all.yml` (Variables File)
Defines all global variables used across the playbooks.
- **Key Variables:**
  - `elk_version`: Set to `"9.4.4"` as required.
  - `container_name`: Elasticsearch container name (`es01`).
  - `data_dir`: Host data directory for Elasticsearch (`/data/es01`).
  - `elasticsearch_image`: Wolfi Elasticsearch hardened image coordinate.
  - `kibana_image_name`: Wolfi Kibana hardened image coordinate.
  - `kibana_container_name`: Kibana container name (`kib01`).
  - `fleet_server_image_name`: Wolfi complete agent image coordinate for Fleet.

### 2. `ansible/setup_elasticsearch.yml` (Elasticsearch Setup Playbook)
Automates the installation of Elasticsearch.
- **Actions:**
  - Detects host OS and installs `podman` and `podman-compose` using `apt` (Ubuntu/Debian) or `dnf` (RHEL/CentOS/AlmaLinux).
  - Prepares the host data directory `/data/es01` with proper permissions (`1000:1000`).
  - Pulls the Elasticsearch hardened Wolfi image.
  - Generates a local `podman-compose.yml` for Elasticsearch.
  - Starts the Elasticsearch service.
  - Resets and retrieves the `elastic` user password, saving it to `elk-wolfi/temp_credentials.txt`.
  - Copy the SSL certificate `http_ca.crt` to the host's `${elk_dir}/certs` directory.
  - Verifies connectivity via `curl`.
  - Generates the Kibana enrollment token.

### 3. `ansible/setup_kibana.yml` (Kibana Setup Playbook)
Automates the installation and configuration of Kibana.
- **Actions:**
  - Checks if Elasticsearch certificate, password, and Podman networks exist.
  - Runs a temporary Kibana container to copy and extract the default `kibana.yml` configuration to the host.
  - Creates the `podman-compose-kibana.yml` compose file.
  - Deploys Kibana with custom configs and starts it.
  - Retrieves the Kibana verification code using `podman exec`.

### 4. `ansible/setup_fleet_server.yml` (Fleet Server Setup Playbook)
Deploys and registers the Elastic Fleet Server agent.
- **Actions:**
  - Confirms Elasticsearch and Kibana setup and retrieves the password.
  - Prompts for (or reads from variables) the Fleet Service Token and Fleet Server Policy ID.
  - Generates the `podman-compose-fleet-server.yml` file.
  - Starts the Fleet Server container as the root user (or configured user).

### 5. `ansible/main.yml` (Primary / Master Playbook)
Import-based playbook that calls the individual playbooks in sequence:
1. `setup_elasticsearch.yml`
2. `setup_kibana.yml`
3. `setup_fleet_server.yml`

---

## Executing the Playbooks

### Running via the Master Bash Script (Recommended)
You can call all playbooks sequentially using the master execution bash script `run_playbooks.sh`:

```bash
chmod +x run_playbooks.sh
./run_playbooks.sh
```

### Running Playbooks Individually
If you want to run any of the playbooks individually with Ansible, use:

```bash
# Set up Elasticsearch only
ansible-playbook -i localhost, -c local ansible/setup_elasticsearch.yml

# Set up Kibana only
ansible-playbook -i localhost, -c local ansible/setup_kibana.yml

# Set up Fleet Server only
ansible-playbook -i localhost, -c local ansible/setup_fleet_server.yml
```

You can pass extra variables (e.g. for Fleet registration) dynamically:
```bash
ansible-playbook -i localhost, -c local ansible/main.yml \
  -e "fleet_server_service_token=YOUR_TOKEN_HERE" \
  -e "fleet_server_policy_id=YOUR_POLICY_ID"
```
