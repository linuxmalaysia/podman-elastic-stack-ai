---
title: "System Tuning & Optimization"
description: "Practical task-based instructions to apply host/kernel modifications for unprivileged Podman deployments."
nav_order: 20
---

# System Tuning & Optimization Guide

This how-to guide explains how to apply mandatory kernel modifications and resource limits on WSL2 or bare-metal Linux.

---

## 🛠️ Task 1: Check & Apply `vm.max_map_count` Limits

Elasticsearch requires a minimum virtual memory allocation parameter to prevent Out Of Memory crashes.


### Step 1: Query the Active Limit

```bash
sysctl vm.max_map_count
```


### Step 2: Set the Count Permanently

On your host or WSL2 environment, edit `/etc/sysctl.conf` or `/etc/sysctl.d/99-elasticsearch.conf` and set:

```text
vm.max_map_count=262144
```

Apply the configuration instantly:

```bash
sudo sysctl --system
```

---

## 📁 Task 2: Fix Inotify Limits for Large Stacks

WSL2 and native Linux distributions have default limitations on directory watch monitors, which can cause compose environments to fail to track file events.


### Step 1: Set Inotify Limits

Write the updated boundaries to `/etc/sysctl.d/50-inotify.conf`:

```text
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512
```

Reload the runtime kernel boundaries:

```bash
sudo sysctl -p /etc/sysctl.d/50-inotify.conf
```
