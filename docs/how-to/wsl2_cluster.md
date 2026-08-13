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
To bind and execute workloads against your multi-node WSL topology, target `inventory/hosts.wsl.3node.yml`:
```yaml
all:
  hosts:
    es-node-01:
      ansible_host: 127.0.0.1
      es_port: 9200
    es-node-02:
      ansible_host: 127.0.0.1
      es_port: 9201
    es-node-03:
      ansible_host: 127.0.0.1
      es_port: 9202
```

### Step 2: Execute the Setup Sequence
```bash
./run_playbooks.sh -i inventory/hosts.wsl.3node.yml
```

---

## 🔍 Task 2: Audit Cluster Status & Cluster Health

Once deployed, make unprivileged status inquiries directly using security-safe parameters.

### Step 1: Check Node Health
```bash
curl -k -u elastic -X GET "https://127.0.0.1:9200/_cluster/health?pretty"
```
*(Provide the secure user password sourced from `elk-wolfi/temp_credentials.txt`.)*
