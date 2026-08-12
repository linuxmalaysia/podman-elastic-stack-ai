---
okf_version: 0.1
type: documentation
title: "ANSIBLE_PLAYBOOK_MAP.md"
description: "Master Playbook and Related Documents Map Guide."
topics: [ansible, playbooks, mapping, architecture, reference]
resource: file:///docs/ANSIBLE_PLAYBOOK_MAP.md
timestamp: 2026-07-12T10:00:00Z
---
{% raw %}
# 🗺️ Master Playbook and Document Matrix

This guide provides a comprehensive dictionary linking automated Ansible playbooks, their core roles, managed services, and corresponding documentation sections.

---

## 1. Operational Objective

Our deployment strategy guarantees that every phase of the automation fabric—specifically infrastructure boots, unprivileged container lifecycle, local developer feedback, security validations, and secondary services (Gitea/Semaphore)—is completely Ansible-driven and fully integrated with our local Markdown documentation.

---

## 2. Playbook and Document Matrix

The table below serves as a directory, tracing every playbook file directly to its roles, managed services, and corresponding documentation chapters:

| Playbook File | Primary Role & Purpose | Services Managed | Related Documents |
| :--- | :--- | :--- | :--- |
| `site.yml` | Primary root-level cluster playbook orchestration | Elasticsearch, Kibana | `INSTALL.md`, `WSL-3NODE-CLUSTER-GUIDE.md` |
| `ansible/setup_elasticsearch.yml` | Deploy Wolfi Elasticsearch cluster/containers | Elasticsearch | `INSTALL.md`, `PLAYBOOKS.md` |
| `ansible/setup_kibana.yml` | Deploy and configure unprivileged Kibana | Kibana | `INSTALL.md`, `PLAYBOOKS.md` |
| `ansible/setup_fleet_server.yml` | Deploy Wolfi Fleet Server container | Fleet Server | `INSTALL.md`, `PLAYBOOKS.md` |
| `ansible/setup_gitea.yml` | Deploy sovereign unprivileged Gitea stack | Gitea, PostgreSQL | `GITEA_GUIDE.md` |
| `ansible/setup_semaphore.yml` | Deploy sovereign unprivileged SemaphoreUI | Semaphore, MySQL | `SEMAPHORE_GUIDE.md` |
| `playbooks/matrix_test.yml` | Local Multi-OS test matrix verification | Podman containers (Ubuntu, Alma, Debian) | `LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md`, `DOCS_MATRIX_TELEMETRY.md` |

---

## 3. Deployment Phases

Our automation fabric enforces a modular, stepwise execution path:

### A. Phase 0: Host Environment Preparation (Rootful Privilege)
Executes system bootstrap routines, package installation, and kernel parameter adjustments (such as `vm.max_map_count` and `fs.inotify.max_user_watches` updates).

### B. Phase 1: Unprivileged Application Provisioning (Rootless Privilege)
Generates user-level configuration templates, registers systemd Quadlet files under user config paths, starts containers, and retrieves secure, cryptographically generated credentials.

---
*DSOM Engineering | Playbook Map Guide v1.0*
{% endraw %}
