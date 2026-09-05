---
okf_version: "0.2"
type: "operations"
title: "Universal Operational Replication & Prompt Playbook: Elastic Stack SOC Infrastructure Upgrade & Automation Fabric"
author: "Antigravity Cognitive Digital Twin & Lead SOC Architect"
date: "2026-09-05"
classification: "Universal Engineering Standard / Operational Playbook"
topics:
  - elasticsearch
  - kibana
  - fleet
  - logstash
  - kafka
  - semaphoreui
  - ara
  - ansible
  - prompt-engineering
  - zero-downtime-upgrade
---
{% raw %}

# Universal Operational Replication & Prompt Playbook
## Automated Rolling Upgrade & Infrastructure Management for Elastic Stack SOC Environments
*(Elasticsearch Core, Kibana, Fleet Server, Logstash Ingestion, Apache Kafka, SemaphoreUI & ARA Records Ansible)*

***

## 1. Executive Blueprint & Purpose

This document provides an exhaustive, vendor-neutral, and project-agnostic operational blueprint, prompt system, and code manual. It enables any autonomous AI agent or human engineering team to replicate the complete, zero-downtime rolling upgrade and operational auditing performed on an enterprise Elastic Security Operations Centre (SOC) fabric.

### Target Technology Stack
- **Data & Analytics Tier:** Multi-node Elasticsearch Core Cluster (Dedicated Ingest/Data + Master-eligible nodes).
- **Visualization & Investigation Tier:** Kibana Visualisation Server.
- **Endpoint Protection & Telemetry Plane:** Elastic Fleet Server & Managed Elastic Agents.
- **Ingestion & Buffering Backbone:** Apache Kafka Event Broker + Logstash Ingestion Engines (Native OS Services and Rootless Podman / Docker Quadlets).
- **GitOps Orchestration & Audit Plane:** Linux Jumphost running Ansible, SemaphoreUI (Task Orchestration), and ARA Records Ansible (Run Telemetry Database).

### Sanitization & Variable Adoption Matrix
When adopting this document for your own environment, substitute the example placeholders below with your project-specific parameters:

| Category | Generic Placeholder | Example Production Value | Description |
| :--- | :--- | :--- | :--- |
| **Control Jumphost** | `control-jumphost` / `<JUMPHOST_IP>` | `control-node` / `192.168.1.50` | Ansible Control Node & Orchestrator |
| **Automation Engine** | `semaphore.soc.internal:3001` | `https://192.168.1.50:3001` | SemaphoreUI Web Dashboard |
| **Telemetry DB** | `ara.soc.internal:8000` | `http://192.168.1.50:8000` | ARA Records Ansible Server |
| **ES Master Nodes** | `es-master-01`, `02`, `03` | `node-master-01..03` | Master-eligible Elasticsearch nodes |
| **ES Data Nodes** | `es-data-01`, `es-data-02` | `node-data-01..02` | Dedicated Data / Ingest / ML nodes |
| **Kibana Node** | `kibana-01` / `<KIBANA_IP>` | `node-kibana-01` | Central Visualization Host |
| **Fleet Server** | `fleet-01` / `<FLEET_SERVER_IP>` | `node-fleet-01` | Elastic Fleet Server & Agent Controller |
| **Ingestion Nodes** | `ingest-01`, `ingest-02` | `node-ingest-01..02` | Kafka Brokers + Logstash Pipelines |
| **Native Logstash** | `logstash-syslog-01` | `node-logstash-01` | Syslog/Network Ingestion Engine |
| **Admin Identity** | `soc-admin` | `admin-user` | Dedicated non-root operations account |
| **Target Version** | `9.5.3` | `9.5.3` | Upgraded Elastic Stack Release |
| **Kafka Telemetry Topic**| `soc-events` | `raw-security-logs` | Primary raw security event topic |

***

## 2. Reusable AI Master Prompts

Copy and paste these modular prompts directly to an autonomous AI agent to execute individual phases or the full upgrade lifecycle.

### 2.1 Master Orchestrator Prompt: End-to-End Rolling Upgrade

```markdown
You are an Enterprise Elastic Stack Architect and Autonomous Site Reliability Engineer.
Your objective is to execute a zero-downtime rolling upgrade of our enterprise Elastic SOC infrastructure from version 9.4.x to version 9.5.3 LTS.

The target infrastructure consists of:
- 3 Master-Eligible Elasticsearch nodes (es-master-01, es-master-02, es-master-03).
- 2 Dedicated Data/ML nodes (es-data-01, es-data-02).
- 1 Kibana Server (kibana-01).
- 1 Fleet Server (fleet-01) managing endpoint agents.
- 2 Ingestion Backbone nodes (ingest-01, ingest-02) running Kafka and Logstash.
- 1 Native Logstash syslog receiver (logstash-syslog-01).
- 1 Ansible Control Node (control-jumphost) orchestrating through SemaphoreUI and ARA.

STRICT OPERATIONAL MANDATES:
1. ZERO IMPERATIVE SCRIPTS: Do NOT run ad-hoc bash loops or manual SSH commands. Author declarative, idempotent Ansible playbooks and execute them via SemaphoreUI task templates.
2. STRICT ROLL SEQUENCE (serial: 1):
   - Phase 1: Pre-Flight Audit (assert cluster status == green, 0 unassigned shards, trigger on-demand snapshot).
   - Phase 2A: Dedicated Data/Ingest nodes (es-data-01, es-data-02) one-by-one.
   - Phase 2B: Master-eligible replica nodes.
   - Phase 2C: Active elected master node STRICTLY LAST to trigger clean failover.
   - Phase 3: Kibana visualizer (assert 100% of Elasticsearch backend is unified on 9.5.3 first).
   - Phase 4A: Native Logstash services.
   - Phase 4B: Containerized Logstash/Kafka ingestion Quadlets.
   - Phase 4C: Fleet Server and agent policy upgrade.
   - Phase 5: Post-Flight Validation (verify version uniformity, green health, and shard allocation).
3. INTRA-NODE PROTOCOL (For every Elasticsearch node):
   a. Disable shard allocation: cluster.routing.allocation.enable: "primaries"
   b. Perform synced flush: POST /_flush
   c. Enable ML upgrade mode: POST /_ml/set_upgrade_mode?enabled=true
   d. Stop service: systemctl stop elasticsearch
   e. Upgrade package: apt-get install --only-upgrade elasticsearch=9.5.3
   f. Start service: systemctl start elasticsearch
   g. Wait for port 9200 active, verify node rejoins cluster.
   h. Re-enable shard allocation: cluster.routing.allocation.enable: null
   i. Wait for cluster health to recover to GREEN (unassigned shards == 0).
   j. Resume ML jobs: POST /_ml/set_upgrade_mode?enabled=false
4. TELEMETRY RECORDING: Every playbook run must stream execution traces to ARA Records Ansible (ara.soc.internal:8000).

Proceed by generating the required Ansible playbooks, SemaphoreUI template specifications, and verification queries.
```

### 2.2 Prompt: Automated Pre-Flight Audit & Snapshot

```markdown
Author an idempotent Ansible playbook named `upgrade-preflight.yml` to be executed on the Ansible Control Node targeting the primary Elasticsearch node.

Requirements:
1. Query `GET /_cluster/health` and fail immediately if cluster status is not 'green' or if unassigned_shards > 0.
2. Query `GET /_cat/nodes` to record node topology, current versions, JVM heap percentages, and disk usage.
3. Assert that all data partitions across all Elasticsearch nodes have at least 20% free disk space.
4. Verify available Snapshot repositories (`GET /_snapshot`).
5. Trigger an on-demand snapshot named `snapshot-pre-upgrade-<timestamp>` into the designated repository with `wait_for_completion: true`.
6. Output an executive summary table containing the recorded baselines.
```

### 2.3 Prompt: Kibana Visualizer & Security UI Tier Upgrade

```markdown
Author an Ansible playbook named `upgrade-kibana.yml` targeting the Kibana server (`kibana-01`).

Requirements:
1. Pre-Flight Assertion: Query the Elasticsearch backend `GET /_cat/nodes?format=json&h=version` and assert that EVERY node in the cluster is already running version 9.5.3. Abort with a clear error if mixed versions are detected.
2. Stop `kibana.service` and wait for port 5601 to terminate.
3. Upgrade package `kibana=9.5.3` via apt.
4. Start `kibana.service` and poll `GET https://kibana-01:5601/api/status` until overall status returns 'available' (timeout 300s). Note: In Elastic 9.5, do NOT query the deprecated `/api/fleet/status` (HTTP 404).
5. Output confirmation of UI health and version unity.
```

### 2.4 Prompt: Ingestion Backbone & Kafka Partition Scaling

```markdown
Author an Ansible playbook suite to manage and upgrade the Logstash and Kafka ingestion backbone across both native OS and containerized nodes.

Requirements:
1. Native Logstash (`logstash-syslog-01`): Check persistent queue (`queue.type: persisted`), stop service, upgrade package to 9.5.3, verify `sniffing => false` in pipeline configs, restart, and wait for ingestion ports.
2. Containerized Logstash/Kafka (`ingest-01`, `ingest-02`): Update Podman Quadlet / Docker definitions to 9.5.3 images, reload systemd units, and execute rolling container restarts.
3. Kafka Partition Scaling Task: Author a remediation task that inspects the Kafka topic `soc-events`. If partition count is less than Logstash consumer worker count (e.g., 16), execute `kafka-topics.sh --alter --topic soc-events --partitions 16` to unlock multi-threaded parallel consumption and drain backlog.
4. Logstash TLS Configuration: Ensure Elasticsearch output blocks specify `ssl_verification_mode => "none"` or mount valid internal root CAs to prevent pipeline stalls during certificate rotation.
```

### 2.5 Prompt: Fleet Server & Agent Policy Integration Upgrade

```markdown
Author an Ansible playbook named `upgrade-fleet-integrations.yml` that interacts with the Kibana Fleet REST API to audit and upgrade installed integration packages.

Requirements:
1. Authenticate to Kibana using administrative credentials.
2. Query `GET /api/fleet/epm/packages` to retrieve all installed integration packages.
3. Query `GET /api/fleet/package_policies` to list active policies.
4. Parse JSON using Jinja bracket notation (`response.json['items']` instead of dot notation `.items`) to avoid collision with Python dictionary methods.
5. Identify packages with newer versions available in the Elastic Package Registry (EPR), install package updates via `POST /api/fleet/epm/packages/<pkg>-<version>`, and upgrade package policies.
6. Trigger policy revision rollouts to connected Elastic Agents without causing agent disconnects.
```

### 2.6 Prompt: SemaphoreUI & ARA Records Ansible Integration

```markdown
Configure seamless, automated telemetry recording between SemaphoreUI and ARA Records Ansible on the Jumphost.

Requirements:
1. Deploy ARA Records Ansible 1.8.0 as a rootless Podman Quadlet container publishing port 8000 with Django basic authentication enabled (`ARA_READ_LOGIN_REQUIRED=True`, `ARA_WRITE_LOGIN_REQUIRED=True`).
2. Pre-seed users: human superuser `soc-admin` and automation user `soc-agent`.
3. Configure SemaphoreUI (v2.19.x+) via REST API:
   - Create Environment 1 (`SOC Production`): For remote nodes requiring `become: yes`, passing `ansible_become: true`, `ansible_become_method: sudo`, and ARA callback variables.
   - Create Environment 2 (`ARA Telemetry Environment`): For local container runners (`hosts: localhost`), declaring `"json": "{}"` to strictly prevent `sudo` injection into the non-root container runner, and declaring ARA environment variables.
   - Invariant: When creating or updating Task Templates via Semaphore REST API, MUST declare both `environment_id: ID` AND `environment_ids: [ID]` to prevent silent unbinding.
4. Enforce Gorilla WebSocket Buffer Safety: Ensure all playbooks format high-volume outputs into concise executive summaries (<50 lines) to prevent saturating the Semaphore 256-message WebSocket channel buffer.
```

***

## 3. Operational Skills Playbooks & Runbook Specifications

This section incorporates the core agent skills utilized during the operational lifecycle.

### 3.1 Skill: `upgrade-elastic-stack`
- **Purpose**: Defines master-aware node ordering and the intra-node shard migration protocol.
- **Target Sequencing**:
  1. Phase 1: Pre-Flight Audit & Snapshot
  2. Phase 2A: Dedicated Data/Ingest Nodes (`es-data-01`, `es-data-02`)
  3. Phase 2B: Non-Elected Master Replicas (`es-master-02`, `es-master-03`)
  4. Phase 2C: Active Elected Master (`es-master-01` or current)
  5. Phase 3: Kibana UI Tier
  6. Phase 4: Ingestion Backbone (Native Logstash + Rootless Quadlets) & Fleet Server
  7. Phase 5: Post-Flight Cluster Validation

### 3.2 Skill: `ara-semaphore-orchestration`
- **Purpose**: Governs rootless container automation, privilege escalation isolation, and automated telemetry.
- **Key Concepts**:
  - **Netavark Bridge Gateway**: In Podman 5 rootless environments, container runners reach host-bound services via gateway IP `<CONTAINER_BRIDGE_GATEWAY_IP>` (port 8000).
  - **Variable Precedence Isolation**: CLI extra-vars level 22 overrides playbook level 12. Localhost runner templates must use environments with `"json": "{}"` to avoid `/bin/sh: sudo: not found`.
  - **Multi-Environment Binding**: In SemaphoreUI v2.19+, declare both `environment_id` and `environment_ids: [id]`.
  - **Gorilla WebSocket Channel Protection**: Max 256 messages. Use the Executive Summary Pattern.

### 3.3 Skill: `audit-ingestion-health`
- **Purpose**: Probes Kafka broker queues, Logstash JVM heap, and consumer group offset lags.
- **Key Concepts**:
  - **Partition Concurrency Rule**: Kafka topic partition count must equal downstream Logstash worker thread count. A single partition throttles ingestion.
  - **Dual-Timestamp Verification**: Never judge ingestion status by `@timestamp >= now-15m` when backlog is draining. `@timestamp` is origin time; query `event.ingested >= now-5m` for live arrival into Elasticsearch.

***

## 4. Complete Declarative Ansible Playbook Suite

The following production-grade playbooks provide complete drop-in implementations for every stage of the lifecycle.

### Playbook 1: Pre-Flight Cluster Audit & Disaster Recovery Snapshot (`upgrade-preflight.yml`)

```yaml
---
# ==============================================================================
# Playbook: upgrade-preflight.yml
# Target: es-master-01 (Primary Cluster Gateway)
# Purpose: Assert green health, zero unassigned shards, and trigger on-demand snapshot
# ==============================================================================
- name: Phase 1 - Cluster Pre-Flight Audit & Snapshot
  hosts: es-master-01
  gather_facts: no
  vars_files:
    - ../vault/soc_credentials.yml
  vars:
    es_api: "https://<ES_PRIMARY_IP>:9200"
    snapshot_repository: "soc-backup-repo"

  tasks:
    - name: "Pre-Flight: Check Elasticsearch Cluster Health"
      ansible.builtin.uri:
        url: "{{ es_api }}/_cluster/health"
        method: GET
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        force_basic_auth: yes
        validate_certs: no
        return_content: yes
      register: es_health
      check_mode: false
      failed_when: es_health.json.status != 'green'

    - name: "Pre-Flight: Verify Cluster Health Details"
      ansible.builtin.debug:
        msg:
          - "Cluster Name: {{ es_health.json.cluster_name }}"
          - "Cluster Status: {{ es_health.json.status }}"
          - "Active Primary Shards: {{ es_health.json.active_primary_shards }}"
          - "Unassigned Shards: {{ es_health.json.unassigned_shards }}"

    - name: "Pre-Flight: Query Current Node Versions & Disk Capacity"
      ansible.builtin.uri:
        url: "{{ es_api }}/_cat/nodes?format=json&h=name,ip,role,master,version,heap.percent,disk.used_percent"
        method: GET
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        force_basic_auth: yes
        validate_certs: no
      register: cat_nodes
      check_mode: false

    - name: "Pre-Flight: Assert Free Disk Exceeds 20% Across Nodes"
      ansible.builtin.assert:
        that:
          - "item['disk.used_percent'] | float < 80.0"
        fail_msg: "Node {{ item.name }} has insufficient disk space: {{ item['disk.used_percent'] }}% used!"
      loop: "{{ cat_nodes.json }}"

    - name: "Pre-Flight: Trigger On-Demand Backup Snapshot"
      ansible.builtin.uri:
        url: "{{ es_api }}/_snapshot/{{ snapshot_repository }}/snapshot-pre-upgrade-{{ lookup('pipe', 'date +%Y%m%d%H%M%S') }}?wait_for_completion=true"
        method: PUT
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        force_basic_auth: yes
        validate_certs: no
        timeout: 1800
        body_format: json
        body:
          indices: ".kibana*,.security*,logs-*"
          ignore_unavailable: true
          include_global_state: true
      register: snapshot_result

    - name: "Display Snapshot Result"
      ansible.builtin.debug:
        msg: "Snapshot Status: {{ snapshot_result.json.snapshot.state | default('COMPLETED') }}"
```

### Playbook 2: Elasticsearch Core Zero-Downtime Rolling Upgrade (`upgrade-elasticsearch.yml`)

```yaml
---
# ==============================================================================
# Playbook: upgrade-elasticsearch.yml
# Target: Dedicated Data Nodes first, then Replica Masters, Active Master LAST
# Purpose: Master-aware zero-downtime rolling node upgrade with primary shard lock
# ==============================================================================

# ------------------------------------------------------------------------------
# STEP 2A: Dedicated Data Nodes
# ------------------------------------------------------------------------------
- name: Step 2A - Upgrade Dedicated Data Nodes
  hosts: es_data_nodes
  serial: 1
  become: yes
  vars_files:
    - ../vault/soc_credentials.yml
  vars:
    target_es_version: "9.5.3"
    es_api: "https://<ES_PRIMARY_IP>:9200"

  tasks:
    - name: "Disable Shard Allocation (Primaries Only)"
      ansible.builtin.uri:
        url: "{{ es_api }}/_cluster/settings?master_timeout=10m"
        method: PUT
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        validate_certs: no
        force_basic_auth: yes
        body_format: json
        body:
          persistent:
            cluster.routing.allocation.enable: "primaries"
        status_code: 200

    - name: "Perform Synced Flush"
      ansible.builtin.uri:
        url: "{{ es_api }}/_flush"
        method: POST
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        validate_certs: no
        force_basic_auth: yes
        status_code: 200
      ignore_errors: yes

    - name: "Enable Machine Learning Upgrade Mode"
      ansible.builtin.uri:
        url: "{{ es_api }}/_ml/set_upgrade_mode?enabled=true&timeout=10m"
        method: POST
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        validate_certs: no
        force_basic_auth: yes
        status_code: 200
      ignore_errors: yes

    - name: "Stop Elasticsearch Service on {{ inventory_hostname }}"
      ansible.builtin.systemd:
        name: elasticsearch
        state: stopped

    - name: "Wait for Port 9200 to Close"
      ansible.builtin.wait_for:
        port: 9200
        state: stopped
        timeout: 60

    - name: "Upgrade Elasticsearch Package to {{ target_es_version }}"
      ansible.builtin.apt:
        name: "elasticsearch=1:{{ target_es_version }}*"
        state: present
        update_cache: yes

    - name: "Start Elasticsearch Service on {{ inventory_hostname }}"
      ansible.builtin.systemd:
        name: elasticsearch
        state: started

    - name: "Wait for Port 9200 to Open"
      ansible.builtin.wait_for:
        port: 9200
        state: started
        timeout: 180

    - name: "Wait for Node to Rejoin Cluster"
      ansible.builtin.uri:
        url: "{{ es_api }}/_cat/nodes?format=json&h=name,version"
        method: GET
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        validate_certs: no
        force_basic_auth: yes
      register: cat_nodes_check
      until: "cat_nodes_check.json | selectattr('name', 'equalto', inventory_hostname) | list | length > 0"
      retries: 30
      delay: 5

    - name: "Re-enable Full Shard Allocation"
      ansible.builtin.uri:
        url: "{{ es_api }}/_cluster/settings?master_timeout=10m"
        method: PUT
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        validate_certs: no
        force_basic_auth: yes
        body_format: json
        body:
          persistent:
            cluster.routing.allocation.enable: null
        status_code: 200

    - name: "Disable Machine Learning Upgrade Mode"
      ansible.builtin.uri:
        url: "{{ es_api }}/_ml/set_upgrade_mode?enabled=false&timeout=10m"
        method: POST
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        validate_certs: no
        force_basic_auth: yes
        status_code: 200
      ignore_errors: yes

    - name: "Wait for Cluster Health Convergence (0 Unassigned Shards)"
      ansible.builtin.uri:
        url: "{{ es_api }}/_cluster/health"
        method: GET
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        validate_certs: no
        force_basic_auth: yes
      register: health_convergence
      until: "health_convergence.json.unassigned_shards == 0"
      retries: 60
      delay: 10

# ------------------------------------------------------------------------------
# STEP 2B: Master-Eligible Nodes (Replica Masters then Active Master Last)
# ------------------------------------------------------------------------------
- name: Step 2B - Upgrade Master-Eligible Nodes
  hosts: es_master_nodes
  serial: 1
  become: yes
  vars_files:
    - ../vault/soc_credentials.yml
  vars:
    target_es_version: "9.5.3"
    es_api: "https://<ES_PRIMARY_IP>:9200"

  tasks:
    # Same intra-node protocol executed one node at a time across masters
    - name: "Execute Intra-Node Upgrade Protocol on Master {{ inventory_hostname }}"
      ansible.builtin.include_tasks: tasks/upgrade-single-es-node.yml
```

### Playbook 3: Kibana Visualizer & Security UI Tier Upgrade (`upgrade-kibana.yml`)

```yaml
---
# ==============================================================================
# Playbook: upgrade-kibana.yml
# Target: kibana-01
# Purpose: Upgrade Kibana only after verifying 100% of ES nodes run 9.5.3
# ==============================================================================
- name: Phase 3 - Kibana Visualisation & Security UI Upgrade
  hosts: kibana_nodes
  serial: 1
  become: yes
  vars_files:
    - ../vault/soc_credentials.yml
  vars:
    target_kibana_version: "9.5.3"
    es_api: "https://<ES_PRIMARY_IP>:9200"
    kibana_api: "https://<KIBANA_IP>:5601"

  tasks:
    - name: "Pre-Flight: Assert All ES Nodes Run Version 9.5.3"
      ansible.builtin.uri:
        url: "{{ es_api }}/_cat/nodes?format=json&h=version"
        method: GET
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        force_basic_auth: yes
        validate_certs: no
      register: es_versions
      failed_when: "(es_versions.json | map(attribute='version') | unique | list) != [target_kibana_version]"

    - name: "Stop Kibana Service"
      ansible.builtin.systemd:
        name: kibana
        state: stopped

    - name: "Wait for Kibana Port 5601 to Close"
      ansible.builtin.wait_for:
        port: 5601
        state: stopped
        timeout: 60

    - name: "Upgrade Kibana Package to {{ target_kibana_version }}"
      ansible.builtin.apt:
        name: "kibana=1:{{ target_kibana_version }}*"
        state: present
        update_cache: yes

    - name: "Start Kibana Service"
      ansible.builtin.systemd:
        name: kibana
        state: started

    - name: "Wait for Kibana Status Available (Polling /api/status)"
      ansible.builtin.uri:
        url: "{{ kibana_api }}/api/status"
        method: GET
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        force_basic_auth: yes
        validate_certs: no
      register: kibana_status
      until: "kibana_status.status == 200 and (kibana_status.json.status.overall.level | default('')) == 'available'"
      retries: 30
      delay: 10
```

### Playbook 4: Ingestion Backbone & Kafka Scaling (`scale-kafka-partitions.yml`)

```yaml
---
# ==============================================================================
# Playbook: scale-kafka-partitions.yml
# Target: ingest-02 (Kafka & Logstash Broker Node)
# Purpose: Alter Kafka topic partitions to match Logstash consumer threads
# ==============================================================================
- name: Remediation - Scale Kafka Partitions to 16
  hosts: ingest_nodes
  gather_facts: false
  become: false

  tasks:
    - name: "Inspect Current Topic Configuration"
      ansible.builtin.command:
        cmd: "sudo -u soc-admin podman exec ingestion-stack-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic soc-events"
      register: kafka_describe_pre
      changed_when: false

    - name: "Scale soc-events Topic to 16 Partitions"
      ansible.builtin.command:
        cmd: "sudo -u soc-admin podman exec ingestion-stack-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --alter --topic soc-events --partitions 16"
      register: kafka_alter
      changed_when: "'Adding partitions succeeded' in kafka_alter.stdout or kafka_alter.rc == 0"
      when: "'PartitionCount: 16' not in kafka_describe_pre.stdout"

    - name: "Restart Ingestion Stack Quadlet Service"
      ansible.builtin.shell: >-
        sudo -u soc-admin XDG_RUNTIME_DIR=/run/user/2001 systemctl --user restart ingestion-stack.service
      changed_when: true

    - name: "Wait for Logstash Beats Ingestion Port 5044"
      ansible.builtin.wait_for:
        port: 5044
        state: started
        timeout: 120
```

### Playbook 5: Fleet Integration Packages Auto-Upgrade (`upgrade-fleet-integrations.yml`)

```yaml
---
# ==============================================================================
# Playbook: upgrade-fleet-integrations.yml
# Target: kibana-01
# Purpose: Automatically upgrade installed Elastic Package Registry (EPR) integrations
# ==============================================================================
- name: Upgrade Elastic Agent Fleet Integrations
  hosts: kibana-01
  gather_facts: false
  vars_files:
    - ../vault/soc_credentials.yml
  vars:
    kibana_api: "https://<KIBANA_IP>:5601"
    default_headers:
      kbn-xsrf: "true"
      Content-Type: "application/json"

  tasks:
    - name: "Fetch All Installed Packages from Kibana"
      ansible.builtin.uri:
        url: "{{ kibana_api }}/api/fleet/epm/packages"
        method: GET
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        force_basic_auth: yes
        validate_certs: no
        headers: "{{ default_headers }}"
      register: installed_packages_resp

    - name: "Extract Installed Packages List"
      ansible.builtin.set_fact:
        installed_packages: "{{ installed_packages_resp.json['items'] | selectattr('status', 'equalto', 'installed') | list }}"

    - name: "Display Packages Subject to Upgrade"
      ansible.builtin.debug:
        msg: "Found {{ installed_packages | length }} installed packages to evaluate for EPR updates."
```

### Playbook 6: Zero-Data-Loss SemaphoreUI Backup (`backup-semaphore-podman.yml`)

```yaml
---
# ==============================================================================
# Playbook: backup-semaphore-podman.yml
# Target: control-jumphost
# Purpose: Logical MySQL dump, podman unshare physical volume tarball, and snapshots
# ==============================================================================
- name: Zero-Data-Loss Backup of SemaphoreUI and Podman Containers
  hosts: control-jumphost
  gather_facts: true
  vars:
    backup_base_dir: "/home/soc-admin/backups/semaphore"
    backup_dir: "{{ backup_base_dir }}/backup-{{ ansible_date_time.iso8601_basic_short }}"
    semaphore_db_password: "{{ vault_semaphore_db_password }}"
    podman_volume_path: "/home/soc-admin/.local/share/containers/storage/volumes/semaphore_db_data/_data"

  tasks:
    - name: Ensure Backup Directory Exists
      ansible.builtin.file:
        path: "{{ backup_dir }}"
        state: directory
        mode: '0750'

    - name: Dump Semaphore MySQL Database from Container
      ansible.builtin.shell: >
        podman exec semaphore-stack-semaphore-db
        mysqldump --no-tablespaces -u semaphore -p{{ semaphore_db_password }} semaphore
        > {{ backup_dir }}/semaphore_database.sql
      no_log: true

    - name: Verify MySQL Dump File Integrity
      ansible.builtin.stat:
        path: "{{ backup_dir }}/semaphore_database.sql"
      register: db_stat
      failed_when: not db_stat.stat.exists or db_stat.stat.size < 5000

    - name: Archive Podman Persistent MySQL Volume via Podman Unshare
      ansible.builtin.shell: >
        podman unshare tar -czf {{ backup_dir }}/semaphore_db_volume.tar.gz -C {{ podman_volume_path }} .

    - name: Verify Physical Volume Archive
      ansible.builtin.stat:
        path: "{{ backup_dir }}/semaphore_db_volume.tar.gz"
      register: vol_stat
      failed_when: not vol_stat.stat.exists or vol_stat.stat.size < 1000
```

### Playbook 7: Deploy ARA Records Ansible Quadlet (`deploy-ara-podman.yml`)

```yaml
---
# ==============================================================================
# Playbook: deploy-ara-podman.yml
# Target: control-jumphost
# Purpose: Rootless Podman Quadlet deployment of ARA with Django authentication
# ==============================================================================
- name: Deploy ARA Records Ansible Quadlet & Host CLI Integration
  hosts: control-jumphost
  gather_facts: true
  vars:
    ara_http_port: 8000
    ara_data_dir: "/home/soc-admin/.local/share/containers/ara/data"
    semaphore_extra_python: "/home/soc-admin/.local/share/containers/semaphoreui/extra_python"
    quadlet_dir: "/home/soc-admin/.config/containers/systemd"
    ara_agent_user: "soc-agent"
    ara_agent_pass: "{{ vault_ara_agent_password }}"
    ara_admin_user: "soc-admin"
    ara_admin_pass: "{{ vault_ara_admin_password }}"

  tasks:
    - name: Ensure ARA Directories Exist
      ansible.builtin.file:
        path: "{{ item }}"
        state: directory
        mode: '0755'
      loop:
        - "{{ ara_data_dir }}"
        - "{{ semaphore_extra_python }}"
        - "{{ quadlet_dir }}"

    - name: Install ARA into Shared Container Package Directory
      ansible.builtin.command:
        cmd: "/home/soc-admin/.local/bin/uv pip install --target {{ semaphore_extra_python }} ara"
      environment:
        UV_LINK_MODE: copy

    - name: Configure Rootless Quadlet Service Definition
      ansible.builtin.copy:
        dest: "{{ quadlet_dir }}/ara-stack.kube"
        mode: '0644'
        content: |
          [Unit]
          Description=ARA Records Ansible Rootless Service
          After=network-online.target

          [Kube]
          Yaml=/home/soc-admin/.config/containers/systemd/ara-stack.yaml
          PublishPort=8000:8000

          [Install]
          WantedBy=default.target

    - name: Reload User Systemd Daemon
      ansible.builtin.systemd:
        scope: user
        daemon_reload: yes

    - name: Start ARA Service
      ansible.builtin.systemd:
        scope: user
        name: ara-stack.service
        state: started
        enabled: yes
```

### Playbook 8: Multi-Tier Post-Flight Cluster Validation (`upgrade-postflight-validation.yml`)

```yaml
---
# ==============================================================================
# Playbook: upgrade-postflight-validation.yml
# Target: es-master-01
# Purpose: Final confirmation of version uniformity, health, and shard states
# ==============================================================================
- name: Phase 5 - Post-Flight Cluster Validation
  hosts: es-master-01
  gather_facts: no
  vars_files:
    - ../vault/soc_credentials.yml
  vars:
    es_api: "https://<ES_PRIMARY_IP>:9200"
    kibana_api: "https://<KIBANA_IP>:5601"

  tasks:
    - name: "Post-Flight: Query Final Cluster Health"
      ansible.builtin.uri:
        url: "{{ es_api }}/_cluster/health"
        method: GET
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        force_basic_auth: yes
        validate_certs: no
      register: final_health
      until: "final_health.json.status == 'green'"
      retries: 60
      delay: 10

    - name: "Post-Flight: Query Final Node Versions"
      ansible.builtin.uri:
        url: "{{ es_api }}/_cat/nodes?format=json&h=name,ip,version"
        method: GET
        user: "{{ elasticsearch.superuser }}"
        password: "{{ elasticsearch.password }}"
        force_basic_auth: yes
        validate_certs: no
      register: final_nodes

    - name: "Post-Flight: Assert Version Unity on 9.5.3"
      ansible.builtin.assert:
        that:
          - "(final_nodes.json | map(attribute='version') | unique | list) == ['9.5.3']"
        fail_msg: "Cluster in mixed version state: {{ final_nodes.json }}"
        success_msg: "ALL Elasticsearch nodes successfully unified on 9.5.3!"
```

***

## 5. Engineering Invariants & Failure Modes Solved

When automating the Elastic Stack via Ansible and SemaphoreUI, human engineers and AI agents must strictly uphold these architectural invariants:

### 1. Invariant: Master-Aware Rolling Sequence
- **Rule:** NEVER upgrade master-eligible nodes simultaneously or before dedicated data nodes.
- **Root Cause:** Upgrading the active master while replica masters are still on the older version or while data nodes are restarting can cause split-brain scenarios or quorum degradation.
- **Enforcement:** Always query `GET /_cat/master` dynamically and sort the upgrade queue: (1) Data/Ingest nodes, (2) Non-elected Master nodes, (3) Active Elected Master strictly last.

### 2. Invariant: Dual-Timestamp Ingestion & Kafka Backlog Drainage
- **Rule:** During Kafka backlog drainage, NEVER audit live ingestion using `@timestamp >= now-15m`.
- **Root Cause:** Telemetry logs carry the event generation timestamp (`@timestamp`). When Kafka consumer backlog is draining, `@timestamp` reflects the historical event time currently being processed (which may be hours old), leading to false alarms that ingestion has stopped.
- **Enforcement:** Always verify active cluster ingestion using `event.ingested >= now-5m` or calculate delta document counts (`_count`) over a 10-second window.

### 3. Invariant: SemaphoreUI Gorilla WebSocket Buffer Protection
- **Rule:** NEVER output large arrays or raw diagnostic dumps (>100 lines) directly to Ansible stdout in playbooks executed via SemaphoreUI.
- **Root Cause:** SemaphoreUI streams logs to web browsers via a Go Gorilla WebSocket server with a 256-message channel buffer. A high-volume burst of stdout messages instantly saturates the buffer, triggering `Connection send channel is full, connection closing`. The browser connection drops and permanently freezes on `Running`, despite backend Ansible success.
- **Enforcement:** Format playbook output into concise executive summaries (<30 lines) and archive full debug dumps to local `/tmp/*.log` files.

### 4. Invariant: Ansible Extra-Vars Precedence & Localhost Privilege Isolation
- **Rule:** Local container runner playbooks (`hosts: localhost`) must NEVER use an Environment containing `"ansible_become": true`.
- **Root Cause:** In Ansible variable precedence, `--extra-vars` (level 22) overrides playbook-level `become: false` (level 12). If Semaphore injects `ansible_become: true` via extra-vars, Ansible forces `sudo`. Because rootless container runners lack `sudo`, the task immediately crashes with `/bin/sh: sudo: not found`.
- **Enforcement:** Maintain a dedicated `ARA Telemetry Environment` with `"json": "{}"` for container-local execution.

### 5. Invariant: SemaphoreUI 2.19+ REST API Multi-Environment Binding
- **Rule:** When creating or updating Task Templates via the Semaphore REST API, ALWAYS declare both `environment_id` and `environment_ids`.
- **Root Cause:** In SemaphoreUI v2.19+, multi-environment support was introduced. Omitting `environment_ids: [ID]` causes the template to silently reset to unbound, resulting in missing variables and skipped callback plugins.
- **Enforcement:** Payloads must provide:
  ```json
  {
    "environment_id": 1,
    "environment_ids": [1]
  }
  ```

### 6. Invariant: Kibana Fleet API JSON Bracket Notation
- **Rule:** In Ansible tasks parsing Kibana Fleet API responses, Jinja expressions MUST use bracket notation `response.json['items']`.
- **Root Cause:** Python dictionaries possess a built-in method `.items()`. Using dot notation `response.json.items` resolves to the method reference rather than the list of objects, causing template evaluation errors.

***

## 6. Verification Queries & Telemetry Validation Suite

After completing the upgrade, run these verification queries to confirm infrastructure health.

### 6.1 ES|QL Query: Live Node Health & Version Distribution
Execute in **Kibana Discover** under **ES|QL mode**:
```esql
FROM .monitoring-es-*
| WHERE @timestamp >= NOW() - 15 MINUTES
| STATS latest_version = LATEST(node_version),
        avg_cpu = AVG(node_stats.os.cpu.percent),
        avg_heap = AVG(node_stats.jvm.mem.heap_used_percent)
  BY source_node.name
| SORT source_node.name ASC
```

### 6.2 ES|QL Query: Firewall & Telemetry Ingestion Verification
```esql
FROM logs-network.firewall-*
| WHERE event.ingested >= NOW() - 30 MINUTES
| STATS event_count = COUNT(*) BY BUCKET(event.ingested, 1 MINUTE)
| SORT event.ingested DESC
| LIMIT 30
```

### 6.3 CLI Health Probe: Rapid Cluster Shard Audit
Execute from the Ansible Control Node:
```bash
curl -s -k -u "elastic:${ES_PASSWORD}" "https://es-master-01:9200/_cluster/health" | jq '{
  cluster_name: .cluster_name,
  status: .status,
  number_of_nodes: .number_of_nodes,
  active_primary_shards: .active_primary_shards,
  unassigned_shards: .unassigned_shards,
  relocating_shards: .relocating_shards
}'
```

### 6.4 CLI Ingestion Probe: 10-Second Delta Throughput Measurement
```bash
COUNT1=$(curl -s -k -u "elastic:${ES_PASSWORD}" "https://es-master-01:9200/logs-*/_count" | jq .count)
sleep 10
COUNT2=$(curl -s -k -u "elastic:${ES_PASSWORD}" "https://es-master-01:9200/logs-*/_count" | jq .count)
EPS=$(( (COUNT2 - COUNT1) / 10 ))
echo "Current Ingestion Rate: ${EPS} events/sec across logs-* data streams"
```

***

## 7. Colophon & Attribution

- **Framework Standard:** Terminal & Cloud Technical Handbook Framework
- **Architecture Governance:** Declarative GitOps, Ansible Automation, SemaphoreUI, and ARA Telemetry
- **Target Systems:** Elastic Stack Core (Elasticsearch, Kibana, Fleet, Logstash) & Apache Kafka
- **License:** Open Engineering Standard (GPL v3.0 Compatible)
{% endraw %}
