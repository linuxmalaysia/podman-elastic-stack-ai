---
okf_version: 0.1
type: documentation
title: "REFERENCE_TUNING.md"
description: "DSOM Reference Tuning URLs and Websites Documentation."
topics: [dsom, tuning, optimization, wsl, references, documentation]
resource: file:///docs/REFERENCE_TUNING.md
timestamp: 2026-07-12T10:00:00Z
---

# 📖 Reference Tuning & Optimization Guide Resources

This document compiles the master reference URLs, websites, and community resources consulted and integrated to implement advanced Kernel Tuning, CPU/Memory calculations, and global optimization settings for WSL2, Podman, and the 3-Node Elasticsearch Cluster.

## 🔗 Primary Resources

### 1. WSL 3-Node Cluster Guide
- **URL**: [https://linuxmalaysia.github.io/podman-elastic-stack-ai/WSL-3NODE-CLUSTER-GUIDE/](https://linuxmalaysia.github.io/podman-elastic-stack-ai/WSL-3NODE-CLUSTER-GUIDE/)
- **Description**: Detailed architecture and requirements for running a distributed 3-node Elasticsearch cluster with quorum, voting, and replication inside Windows Subsystem for Linux (WSL2).

### 2. Optimizing WSL2 for Claude Code: Complete Performance Tuning Guide (2026)
- **URL**: [https://www.thetributary.ai/blog/optimizing-wsl2-claude-code-performance-guide/](https://www.thetributary.ai/blog/optimizing-wsl2-claude-code-performance-guide/)
- **Description**: Comprehensive guide on maximizing performance in WSL2 environments. Contains hardware targets, kernel tuning configurations (like memory allocations, system limits, and inotify watches), and disk compaction techniques.

---

## 🛠️ Optimizations Integrated

The following tuning metrics have been successfully integrated into our automated Ansible Playbook workflows based on these references:

### Kernel / OS-level Tuning
- **`vm.max_map_count`**: Checked and set to at least `262144` for Elasticsearch cluster stability.
- **`fs.inotify.max_user_watches`**: Increased to `524288` to support complex file-watching environments and large code workspaces.
- **Open Files Limits**: Boosted `nofile` soft/hard limits to `65535` in `/etc/security/limits.conf` to avoid "Too many open files" errors.

### Per-Distribution Tuning (`/etc/wsl.conf`)
- **Systemd Enabled**: Sets `systemd=true` for proper service management under WSL2.
- **Automount Metadata**: Configures `metadata,umask=22,fmask=11` to preserve Linux file permission metadata.
- **Network Resolution**: Ensures `generateHosts=true` and `generateResolvConf=true`.
- **Interop and GPU**: Explicitly enables Windows interop and GPU acceleration.

### Global Virtual Machine Tuning (`.wslconfig`)
- **Memory Scaling**: Dynamically calculated based on system total RAM (e.g., 10GB for <=16GB systems, 22GB for 32GB, 48GB for 64GB, and 96GB for 128GB).
- **CPU Allocations**: Configures processors to match host system logical threads (`ansible_processor_vcpus`).
- **Disk and Memory Reclamation**: Enables experimental settings such as `autoMemoryReclaim=gradual` and `sparseVhd=true` to automatically shrink virtual hard drives and release cache.
- **Mirrored Networking & DNS Tunneling**: Leverages `networkingMode=mirrored` and `dnsTunneling=true` for bidirectional localhost mapping and corporate VPN-friendly DNS routing.
