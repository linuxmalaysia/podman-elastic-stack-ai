---
title: "CLI Scripts Reference"
description: "Reference guide detailing variables, arguments, and interface signatures of all operational CLI scripts."
nav_order: 10
---

# CLI Scripts Reference

This reference details the entrypoints, arguments, environment variables, dependencies, inputs, and outputs of all core bash and python scripts within the repository.

---

## 🚀 Setup & Execution Scripts

### 1. `setup_elasticsearch.sh`
* **Purpose**: Automates the deployment of Elasticsearch (using the hardened Wolfi image) inside a Podman network.
* **Dependencies**: `podman`, `podman-compose`, `curl`, `openssl`, `grep`, `sed`.
* **Environment Variables**:
  - `BIND_ADDRESS`: IP interface to bind ports (default: `127.0.0.1`).
* **Command-line Interface**:
  ```bash
  ./setup_elasticsearch.sh
  ```
* **Inputs & Outputs**:
  - **Inputs**: Sourced common helpers from `scripts/utils.sh`.
  - **Outputs**:
    - Generates user password and Kibana enrollment token, saving them in `elk-wolfi/temp_credentials.txt`.
    - Generates TLS certificate at `elk-wolfi/certs/http_ca.crt`.

### 2. `setup_kibana.sh`
* **Purpose**: Automates the setup of Kibana with connection verification to the active Elasticsearch cluster.
* **Dependencies**: `podman`, `podman-compose`, `curl`, `grep`.
* **Environment Variables**:
  - `BIND_ADDRESS`: IP interface to bind Kibana port (default: `127.0.0.1`).
* **Inputs & Outputs**:
  - **Inputs**: Reads credentials from `elk-wolfi/temp_credentials.txt`.
  - **Outputs**:
    - Creates custom configuration `elk-wolfi/kibana.yml`.
    - Spins up the container using compose file `elk-wolfi/podman-compose-kibana.yml`.

### 3. `setup_fleet_server.sh`
* **Purpose**: Deploys an unprivileged instance of Fleet Server for unified agent operations.
* **Environment Variables**:
  - `BIND_ADDRESS`: Defaults to `127.0.0.1`.

### 4. `run_playbooks.sh`
* **Purpose**: Command-line wrapper that coordinates complex, multi-playbook sequences.
* **Arguments**: Accepts standard Ansible options or path variables (e.g., `--inventory` or `-i`).

---

## 📊 Telemetry & Feedback Scripts

### 5. `scripts/jules_gh_feedback.sh`
* **Purpose**: Parses Ansible telemetry reports into a structured Markdown output.
* **Dependencies**: `jq`, `gh` CLI.
* **Environment Variables**:
  - `GITHUB_PR_NUMBER`: The active PR identifier to post comments.
* **Inputs**: Reads execution log from `/tmp/jules_telemetry.json`.
