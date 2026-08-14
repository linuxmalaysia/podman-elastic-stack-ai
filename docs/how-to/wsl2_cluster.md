---
title: "Distributed WSL2 Cluster Operations"
description: "How to operate, manage, and scale a 3-node simulated cluster on WSL2 environments."
nav_order: 21
---

# Distributed WSL2 Cluster Operations

This guide provides practical directions for establishing and operating a 3-node simulated HA cluster on Windows Subsystem for Linux (WSL2) using Podman.

---

## 🏗️ Task 1: Initialize the Multi-Node Topology

We manage simulated clustered deployments via targeted inventory setups.


### Step 1: Target the Custom Inventory

To bind and execute workloads against your multi-node WSL topology, target `inventory/hosts.wsl.3node.yml`. The following is the conceptual inventory representation showing the node variables and the required structure matching our repository schema:

```yaml
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: "{{ ansible_playbook_python }}"
  vars:
    # WSL 3-Node Cluster Configuration Details
    cluster_name: "dsom-wsl-cluster"
    storage_base: "/opt/dsom-persistence/data"
    kibana_port: 5601

    # Nodes configuration mapping host ports and container transports
    nodes:
      - name: "es-node-01"
        http_port: 9200
        transport_port: 9300
      - name: "es-node-02"
        http_port: 9201
        transport_port: 9301
      - name: "es-node-03"
        http_port: 9202
        transport_port: 9302
```


### Step 2: Execute the Setup Sequence

```bash
./run_playbooks.sh -i inventory/hosts.wsl.3node.yml
```

---

## 🔍 Task 2: Audit Cluster Status & Cluster Health

Once deployed, make unprivileged status inquiries directly using security-safe parameters.


### Step 1: Check Node Health

We verify the health of our cluster using the local trusted CA certificate bundle generated during the setup phase. Using curl's secure `--cacert` option guarantees transport trust, while the `-u elastic` prompt asks securely for your dynamic password:

```bash
# Securely verify cluster health without bypassing SSL certificate checks
curl --cacert elk-wolfi/certs/http_ca.crt -u elastic -X GET "https://127.0.0.1:9200/_cluster/health?pretty"
```

*(When prompted, input the dynamic password generated during your step 1 installation, or read it securely from `elk-wolfi/temp_credentials.txt`.)*
