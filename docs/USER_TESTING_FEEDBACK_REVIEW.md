---
okf_version: 0.1
type: documentation
title: "USER_TESTING_FEEDBACK_REVIEW.md"
description: "Review and analysis of user testing findings report on WSL2 notebook deployment."
topics: [dsom, testing, wsl2, podman, elasticsearch, review]
resource: file:///docs/USER_TESTING_FEEDBACK_REVIEW.md
timestamp: 2026-08-12T10:00:00Z
---
# 📊 User Testing Feedback Review & Action Plan

## 1. Executive Overview

This document presents a thorough technical review of the findings report prepared by **Skywalker** (dated 12 August 2026) following feasibility testing of the **Podman Elastic Stack AI** package on a resource-constrained notebook running Windows 11 with WSL2 (Ubuntu 26.04 LTS, 8 GB physical RAM).

The test provided a partial and unsustained validation that a 3-node Elasticsearch 9.4.4 cluster with Kibana 9.4.4 can be initialized under rootless Podman in WSL2. However, due to memory constraints on an 8 GB host, Kibana was subsequently killed by the Linux Out-Of-Memory (OOM) killer. The review below evaluates the nine issues encountered during testing, provides technical root-cause analyses, outlines current repository capabilities, and proposes actionable enhancements for playbooks and documentation.

---

## 2. Technical Evaluation of Reported Issues

| # | Reported Issue | Root Cause Analysis | Existing Project Safeguards & Planned Improvements | Status |
|---|---|---|---|---|
| **1** | `containers-common` package conflict (0.66.0 vs 0.68.0) on Ubuntu 26.04 | Pre-installed legacy Debian/Ubuntu container packages conflicting with newer Podman dependencies during fresh `apt install`. | Updated `docs/INSTALL.md` and `docs/WSL-3NODE-CLUSTER-GUIDE.md` with explicit clean package purging steps (`sudo apt-get purge -y golang-github-containers-common`) before installation. | **Addressed via Docs** |
| **2** | `ansible-core` package 404 error (stale mirror cache) | APT package index not updated prior to package installation on newly provisioned WSL2 distributions. | Playbook `ansible/setup_elasticsearch.yml` includes `apt: update_cache: yes`. Additional documentation added to refresh package lists before manual installs. | **Addressed** |
| **3** | Missing `containers.podman` Ansible collection | Playbook tasks require `containers.podman` execution modules. | Declared in `collections/requirements.yml`. Standard installation command `ansible-galaxy collection install -r collections/requirements.yml` documented across all setup guides. | **Addressed** |
| **4** | `sudo` password prompts blocking non-interactive Ansible `become` tasks | Ansible `become: true` tasks require passwordless elevation when running locally in WSL2. | Documented passwordless `sudo` (`NOPASSWD`) configuration in `/etc/sudoers.d/` in `docs/INSTALL.md` and `docs/WSL-3NODE-CLUSTER-GUIDE.md`. | **Addressed** |
| **5** | Rootless Podman storage path permission error (`/var/lib/containers/storage`) | Default rootless storage configuration attempting to access privileged system paths without user storage configuration. | Playbook automatically creates rootless storage config in `~/.config/containers/storage.conf` when user session requires unprivileged storage paths. | **Addressed** |
| **6** | `node.lock` permission denied due to UID/GID mismatch in rootless namespace | Rootless Podman maps subuid/subgid namespaces where host ownership `1000:1000` must align with container UID 1000 inside the user namespace. | Added explicit `podman unshare chown -R 1000:1000` operational guidance and automated volume chown steps in `ansible/setup_elasticsearch.yml` for rootless persistence directories. | **Addressed** |
| **7** | `xpack.security.enrollment.enabled` missing in Elasticsearch config | Auto-enrollment setting required if generating tokens for automated Kibana token enrollment. | Standard WSL2 3-node cluster configuration uses pre-configured internal TLS certificates and direct `kibana.yml` service account bindings, rendering token enrollment optional. | **Addressed** |
| **8** | Kibana enrollment token TLS SAN mismatch & PEM certificate setup | Token-based enrollment expects JKS keystores or matching IP SANs, whereas custom multi-node setups use static PEM certificates. | The project explicitly configures `kibana.yml` with `elasticsearch.username: "elastic"` and `elasticsearch.password: "elastic"` (or `kibana_system`) with trusted authority certificates (`http_ca.crt`). | **Addressed** |
| **9** | Kibana process killed by OOM killer on 8 GB RAM notebook | Running 3 Elasticsearch nodes + Kibana exceeds default WSL2 RAM allocation (~3.7 GB / 50% host RAM). | Note that `ansible/tasks/wsl_tuning.yml` calculates WSL memory as host RAM + 2 GB, clamped to host RAM - 2 GB (yielding 6 GB for an 8 GB host). This playbook-generated setting takes precedence over the manual `memory=12GB` example in `docs/WSL-3NODE-CLUSTER-GUIDE.md`. Added tuning parameters to `docs/REFERENCE_TUNING.md` and `docs/WSL-3NODE-CLUSTER-GUIDE.md`. Single-node deployment recommended as default for <= 8 GB RAM machines. | **Addressed** |

---

## 3. Review of Recommendations & Operational Action Items

### Recommendation 1: Hardware System Requirements Guidance

- **Tester Recommendation:** Minimum 16 GB RAM for 3-node cluster mode; treat 8 GB RAM as bare minimum.
- **Project Action:**
  - Updated `docs/WSL-3NODE-CLUSTER-GUIDE.md` and `docs/INSTALL.md` to mandate **16 GB physical host RAM** for multi-node deployments.
  - Specified single-node mode (`deployment_option: single_node`) as the primary path for machines with 8 GB RAM.

### Recommendation 2: Playbook Hardening for Rootless & Security

- **Tester Recommendation:** Fix playbook for rootless storage permissions, data directory ownership, and credential handling.
- **Project Action:**
  - Standardized rootless namespace directory ownership in `ansible/setup_elasticsearch.yml` using `podman unshare`.
  - Configured `kibana.yml` using service account tokens / `kibana_system` credentials and certificate authorities instead of interactive enrollment tokens for WSL2 cluster deployments.

### Recommendation 3: Repository URL & Documentation Consistency

- **Tester Recommendation:** Point all clone instructions to active repository (`linuxmalaysia/podman-elastic-stack-ai`).
- **Project Action:**
  - Audited and updated all documentation references (`README.md`, `docs/INSTALL.md`, `docs/GITEA_GUIDE.md`) to point consistently to `https://github.com/linuxmalaysia/podman-elastic-stack-ai.git`.

### Recommendation 4: Deployment Mode Selection Guidance

- **Tester Recommendation:** Offer single-node mode as default demo path for resource-constrained client machines.
- **Project Action:**
  - Default `deployment_option` in `ansible/group_vars/all.yml` remains single-node for maximum compatibility, while 3-node mode is explicitly documented with hardware prerequisites.

---

## 4. Conclusion

The user testing feedback from Skywalker provided valuable field verification of the Podman Elastic Stack AI deployment on Windows 11 WSL2 environments. The nine identified issues have been analyzed and technical mitigations have been incorporated into our documentation, Ansible playbooks, and system requirements matrix to ensure a seamless setup experience.
