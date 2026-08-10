---
okf_version: 0.1
type: documentation
title: "WSL-3NODE-CLUSTER-GUIDE.md"
description: "DSOM documentation file."
topics: [dsom, cluster, node, wsl, documentation]
resource: file:///WSL-3NODE-CLUSTER-GUIDE.md
timestamp: 2026-07-12T09:05:22Z
---
# 🐧 WSL 3-Node Cluster Guide (Elasticsearch 9.x)

## 🎯 Objective
Run a fully functional **3-Node Elasticsearch Cluster + Kibana** configuration on a single **Windows Subsystem for Linux (WSL2)** instance using Podman.

> **Why?** To simulate a distributed production architecture (Quorum, Voting, Shard Replication) on a developer laptop.

## 📋 Prerequisites

### 1. Hardware
-   **RAM**: Minimum 16GB System RAM (WSL needs ~10GB).
-   **WSL Config**: Ensure `.wslconfig` (in Windows User Profile) allows enough RAM.
    ```ini
    [wsl2]
    memory=12GB
    processors=8
    ```

### 2. Software
-   **Podman**: Installed in WSL (`sudo apt install podman`).
-   **Ansible**: Installed in WSL (`sudo apt install ansible`).
-   **Python3**: Installed.

### 3. Kernel Tuning (Critical)
Elasticsearch requires `vm.max_map_count` to be at least 262144.
```bash
# Verify
sysctl vm.max_map_count

# Set (Temporary)
sudo sysctl -w vm.max_map_count=262144

# Set (Permanent - /etc/sysctl.conf)
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

---

## 🚀 Step 1: Configuration

1.  **Clone the Repository** (if you haven't already) to your WSL filesystem (`/home/user/...`).
2.  **Verify Inventory**:
    Check `inventory/hosts.wsl.3node.yml`. This file defines:
    -   3 Nodes: `es-node-01`, `es-node-02`, `es-node-03`.
    -   Ports: `9200`, `9201`, `9202` (HTTP) & `9300`, `9301`, `9302` (Transport).
    -   Kibana: Port `5601`.
    -   Storage: `/opt/dsom-persistence/data`.

3.  **Update Config** (Optional):
    Edit `inventory/hosts.wsl.3node.yml` to update your `ansible_user` and `dsom_group` (default: `your_username`).

    ```bash
    # Quick replace (example for user 'haris')
    sed -i 's/your_username/haris/g' inventory/hosts.wsl.3node.yml
    ```

---

## 🛠️ Step 2: Deployment

Run the deployment script pointing to the specific multi-node inventory.

```bash
# Usage:
ansible-playbook -i inventory/hosts.wsl.3node.yml site.yml
```

> **Note**: This will pull images (~1GB), create certificates, and launch 4 containers.

---

## ✅ Step 3: Verification

### 1. Check Containers
You should see 4 containers running.
```bash
podman ps
```
*Expected Output:*
-   `dsom-persistence-es-node-01`
-   `dsom-persistence-es-node-02`
-   `dsom-persistence-es-node-03`
-   `dsom-kibana-kibana-local`

### 2. Verify Cluster Health
Check if the cluster formed a quorum (Green status).
```bash
# Using the generated credentials (if any) or default
curl -k -u elastic:elastic https://localhost:9200/_cluster/health?pretty
```

*Expected JSON:*
```json
{
  "cluster_name" : "dsom-wsl-cluster",
  "status" : "green",
  "number_of_nodes" : 3,
  "number_of_data_nodes" : 3
}
```

---

## 🖥️ Step 4: Access Kibana

1.  Open your Windows Browser.
2.  Navigate to: **[http://localhost:5601](http://localhost:5601)**
3.  Login:
    -   User: `elastic`
    -   Password: (Check `vault/persistence_secrets.yml` or default `elastic` if reset).

---

## 🧹 Teardown

To remove the cluster and data:
```bash
# 1. Stop and Remove Containers
podman rm -f dsom-persistence-es-node-01 dsom-persistence-es-node-02 dsom-persistence-es-node-03 dsom-kibana-kibana-local

# 2. Cleanup Data (Optional - WARNING: Destructive)
sudo rm -rf /opt/dsom-persistence
```

---
*DSOM Engineering | WSL Multi-Node Guide v1.0*
