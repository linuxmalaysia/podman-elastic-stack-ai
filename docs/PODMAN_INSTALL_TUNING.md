---
okf_version: 0.1
type: documentation
title: "Podman 5+ Installation, Tuning & Security Guide"
description: "Comprehensive guide for installing Podman 5+, performance tuning, security hardening, rootless execution, podman-docker, and D-Bus socket emulation."
topics: [podman, installation, tuning, security, rootless, socket]
resource: file:///docs/PODMAN_INSTALL_TUNING.md
timestamp: 2026-07-12T10:00:00Z
---

# 🦭 Rootless Podman 5+ Installation, Performance Tuning & Security Hardening Guide

This document provides complete instructions for installing, performance tuning, and securing **Podman 5+** in an unprivileged, rootless multi-node or single-node environment. It covers identity bootstrapping (e.g. `dsom-admin` UID/GID 2001), systemd lingering, kernel optimization (`sysctl`), socket emulation via `podman-docker`, and non-root execution fallbacks.

---

## 1. Executive Summary & Architecture Overview

Modern container orchestration demands rootless execution to minimize host attack surfaces. Running containers as `root` introduces significant vulnerabilities where runtime escapes could compromise the host OS. Rootless Podman 5+ leverages user namespaces (`userns`), cgroups v2, and systemd Quadlets to run containerized workloads entirely within unprivileged user boundaries.

### Key Deployment Metrics

| Component | Target Parameter | Implementation Detail |
| :--- | :--- | :--- |
| **Runtime** | Podman 5.0+ | Installed via native distribution repositories (`apt` / `dnf`) |
| **Service Identity** | Service Account (`dsom-admin`) | Dedicated non-root account (UID 2001, GID 2001) |
| **Session Persistence** | Systemd Lingering | `loginctl enable-linger dsom-admin` |
| **Docker Emulation** | `podman-docker` & `podman.socket` | Provides drop-in `/run/user/2001/podman/podman.sock` compatibility |
| **Kernel Hardening** | Dynamic `sysctl` | `vm.max_map_count=1048576`, `fs.file-max=1048576+`, `net.core.somaxconn=65535` |

---

## 2. OS Package Installation

### A. Debian / Ubuntu 24.04+ LTS

On Debian/Ubuntu family distributions, install `podman`, `slirp4netns`, `uidmap`, `crun`, `dbus-user-session`, and `podman-docker`:

```bash
sudo apt-get update
sudo apt-get install -y podman slirp4netns uidmap crun dbus-user-session podman-docker
```

### B. RHEL / AlmaLinux / Rocky Linux / Oracle Linux 9+

On RedHat family distributions, install `podman`, `slirp4netns`, `shadow-utils`, and `podman-docker`:

```bash
sudo dnf install -y podman slirp4netns shadow-utils podman-docker
```

---

## 3. Dedicated Identity & SubUID / SubGID Setup

To prevent UID/GID allocation overlaps across cluster nodes and simplify backup/restore host path permissions, create a unified service user `dsom-admin` with fixed UID `2001` and GID `2001`.

```bash
# 1. Create group and user with fixed ID 2001
sudo groupadd -g 2001 dsom-admin
sudo useradd -u 2001 -g 2001 -m -s /bin/bash dsom-admin

# 2. Verify subuid and subgid range allocations
grep dsom-admin /etc/subuid /etc/subgid
# Example output: dsom-admin:100000:65536

# 3. Enable systemd lingering for persistent rootless execution across logouts
sudo loginctl enable-linger dsom-admin
```

---

## 4. Understanding `podman-docker` & Socket Emulation

### What is `podman-docker`?

`podman-docker` is a lightweight wrapper package that installs a symlink or script named `/usr/bin/docker` which redirects standard `docker` CLI commands directly to `podman`. This allows legacy scripts, Docker-based CI/CD pipelines, and third-party tools (such as Testcontainers or Docker Compose) to transparently execute on top of Podman without altering command syntax.

### Enabling the Docker API Socket (`podman.socket`)

Many containerized applications and management UI tools interact directly with the Docker daemon API socket at `/var/run/docker.sock`. Under rootless Podman, user-level API sockets are served at `/run/user/2001/podman/podman.sock`.

To enable system-wide or user-level socket emulation:

```bash
# User-level D-Bus socket for dsom-admin (rootless UID 2001):
systemctl --user enable --now podman.socket

# System-wide Docker socket symlink pointing to dsom-admin rootless socket:
sudo ln -sf /run/user/2001/podman/podman.sock /var/run/docker.sock

# Suppress "Emulate Docker CLI" warnings:
sudo touch /etc/containers/nodocker
```

---

## 5. Kernel & System Tuning for Production Workloads

Elasticsearch, Logstash, and high-throughput SIEM components require elevated memory-map and socket connection limits.

### Hardened `sysctl` Settings (`/etc/sysctl.d/99-dsom-tuning.conf`)

```ini
# Elasticsearch memory mapping requirement
vm.max_map_count = 1048576

# Dynamic file handle and process limits
fs.file-max = 1048576
fs.inotify.max_user_watches = 524288
kernel.pid_max = 65536

# Swappiness and I/O tuning
vm.swappiness = 1
vm.overcommit_memory = 1

# Network connection backlogs
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_max_syn_backlog = 32768
```

Apply settings live:

```bash
sudo sysctl -p /etc/sysctl.d/99-dsom-tuning.conf
```

---

## 6. Non-Root & Unprivileged Host Fallbacks

When deploying in environments where root privileges (`sudo`) are unavailable (such as restricted HPC clusters or unprivileged VM shells):

1. **Kernel Tuning Graceful Fallback**: The Ansible playbooks check for administrative privileges before executing privileged `sysctl` or system package management tasks. If unprivileged, tasks record a status warning and continue execution.
2. **User-Space Quadlets**: All systemd Quadlet container definitions (`.container`, `.kube`) are stored in `~/.config/containers/systemd/` and managed using unprivileged D-Bus commands (`systemctl --user daemon-reload`).
3. **Environment Variable Exports**:

```bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
```

---

*Podman Elastic Stack AI | Podman 5+ Installation & Tuning Guide v1.0*
