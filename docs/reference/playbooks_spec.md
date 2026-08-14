---
title: "Ansible Playbooks Spec"
description: "Technical reference detailing the roles, variable hierarchies, connections, and telemetry models of our playbooks."
nav_order: 11
---

# Ansible Playbooks Spec

This reference documents the system architectures, entrypoints, variable rules, and connection modes of our orchestration system.

---

## 🏗️ Playbook Registry

### 1. `ansible/setup_elasticsearch.yml`
* **Entrypoint**: `site.yml` or executed standalone.
* **Connection Type**: Evaluates to `local` for localhost execution, or switches to SSH connections dynamically depending on target configurations.
* **Roles & Tasks**:
  - **Step 0**: `tasks/wsl_tuning.yml` (triggered if `deployment_option: wsl2`).
  - **Step 1**: Preflight checks, container base directories provisioning, environment audits.
* **Hardening Features**: Passes credential parameters using `no_log: true` to guarantee privacy and security.

### 2. `ansible/setup_gitea.yml`
* **Purpose**: Sets up Gitea rootless within Podman managed under systemd service scopes.
* **Key Variables**:
  - `gitea_port`: Host binding port (default: `3000`).
  - `gitea_ssh_port`: Default `2222`.

### 3. `ansible/setup_semaphore.yml`
* **Purpose**: Configures Sovereign SemaphoreUI utilizing Quadlet systemd service units.
* **Key Variables**:
  - `semaphore_timezone`: Locked to GMT+8 (`Asia/Kuala_Lumpur`).

---

## 📊 Developer Mode Telemetry

If `execution_mode: dev` is defined, task executions invoke automated metrics tracking.

* **Destination File**: `/tmp/jules_telemetry.json`
* **Collected Metrics**:
  - Start/End timestamps.
  - Active execution path.
  - Exception blocks and exit statuses.
