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

### 3. WSL2 AI Performance & Security Tuning Guide
- **URL**: [WSL2_AI_PERFORMANCE_TUNING.md](WSL2_AI_PERFORMANCE_TUNING.md)
- **Script**: `scripts/wsl2_ai_tuning.py`
- **Description**: Dedicated project guide and `uv` Python tuning/auditing script for Podman 5+, Claude Code, Gemini CLI, AlmaLinux 10, and Ubuntu 26.04 LTS.

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
- **Active Configuration Path**: Written directly to the active Windows user profile directory at `%UserProfile%\.wslconfig` (resolved dynamically inside WSL using PowerShell/cmd.exe path querying and `wslpath` translation).
- **Memory Scaling**: Dynamically calculated based on system total RAM (e.g., 10GB for <=16GB systems, 22GB for 32GB, 48GB for 64GB, and 96GB for 128GB).
- **Hardware-Validated Guardrails**: Automatically queries Windows host hardware details via PowerShell if available, clamping the memory selection to guarantee it never exceeds actual physical host RAM.
- **CPU Allocations**: Configures processors to match host system logical threads (`ansible_processor_vcpus` or Windows query).
- **Disk and Memory Reclamation**: Enables experimental settings such as `autoMemoryReclaim=gradual` and `sparseVhd=true` to automatically shrink virtual hard drives and release cache.
- **Mirrored Networking & DNS Tunneling**: Leverages `networkingMode=mirrored` and `dnsTunneling=true` for bidirectional localhost mapping and corporate VPN-friendly DNS routing.

### 🔄 Required Shutdown & Restart Sequence

Because global virtual machine parameters (`.wslconfig`) and distribution parameters (`/etc/wsl.conf`) require a clean state transition, the following steps must be run:
1. Save work and exit the WSL shell.
2. From Windows Command Prompt or PowerShell, run:
   ```cmd
   wsl.exe --shutdown
   ```
3. Restart your WSL distribution (e.g., open a new WSL terminal) for the new parameters, memory limits, and `/etc/wsl.conf` settings to be fully active.
