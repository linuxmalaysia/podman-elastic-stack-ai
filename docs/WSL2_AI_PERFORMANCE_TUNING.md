---
okf_version: 0.1
type: documentation
title: "WSL2 AI Performance & Security Tuning Guide"
description: "Comprehensive WSL2 performance tuning, networking, and security architecture guide for Podman 5+, Claude Code, Gemini CLI, and AI workloads on AlmaLinux 10 and Ubuntu 26.04 LTS."
topics: [wsl2, podman, claude-code, gemini-cli, ai, tuning, security, almalinux, ubuntu]
resource: file:///docs/WSL2_AI_PERFORMANCE_TUNING.md
timestamp: 2026-08-12T12:00:00Z
---
# 🚀 WSL2 AI Performance & Security Tuning Guide

## 1. Executive Summary & Core Architectural Principles

Developing and running agentic AI workflows—such as **Claude Code**, **Gemini CLI**, **Ollama**, and **Podman 5+** containerized AI stacks—inside Windows Subsystem for Linux 2 (WSL2) offers a real Linux kernel (6.6+), native `ext4` filesystem speed, and unprivileged sandboxing execution while retaining the Windows 11 desktop environment.

This guide extracts and operationalizes key performance research from the [Tributary WSL2 Performance Guide](https://www.thetributary.ai/blog/optimizing-wsl2-claude-code-performance-guide/) and combines it with our enterprise **Podman Elastic Stack AI** architecture. It focuses specifically on the modern Linux enterprise targets:

* **AlmaLinux 10** (RPM / `dnf` ecosystem, enterprise-grade stability)
* **Ubuntu 26.04 LTS** (Debian / `apt` ecosystem, widespread AI developer adoption)

---

## 2. Target Linux Distributions Comparison

| Architecture Feature | AlmaLinux 10 (RPM) | Ubuntu 26.04 LTS (Debian) |
|---|---|---|
| **Package Manager** | `dnf` / `dnf5` | `apt` / `apt-get` |
| **Container Engine** | Podman 5.x native (rootless Quadlet) | Podman 5.x native (rootless Quadlet) |
| **Sandboxing Packages** | `bubblewrap`, `socat` | `bubblewrap`, `socat` |
| **AI Toolchain Support** | Python 3.12+, Node.js v22/v24, `uv` | Python 3.12+, Node.js v22/v24, `uv` |
| **Systemd Init** | Configured per-distro via `/etc/wsl.conf` | Configured per-distro via `/etc/wsl.conf` |

> ℹ️ **Note on Systemd:** Systemd is not active by default in all stock distribution tarballs. You must explicitly configure `[boot] systemd=true` in `/etc/wsl.conf` and restart WSL via `wsl.exe --shutdown` to verify systemd service manager initialization.

---

## 3. Native Linux Filesystem vs. 9P Bridge Performance (~9x Win)

Cross-filesystem file operations (accessing `/mnt/c/` or `/mnt/d/` from inside WSL2) rely on the **9P protocol bridge** to translate Linux kernel calls to the Windows NTFS driver. This introduces massive latency during AI model indexing, ripgrep file searches, and container operations.

### Benchmark Data (Direct Write / Read Direct I/O)

```text
Filesystem                     Path                        Throughput     Relative Speed
Linux ext4 (WSL2 Native)       ~/projects/                 ~1.0 GB/s      1.0x (Optimal)
Windows NTFS (via 9P Mount)    /mnt/c/Users/.../projects   ~110 MB/s      ~0.11x (~9x Slower)
```

> ⚡ **Mandatory Rule:** Store all code repositories, AI vector indices, and container volume mounts in the native Linux home directory (e.g., `~/projects/` or `/home/<user>/projects/`). Never run `podman`, `claude`, or `gemini` commands directly on `/mnt/c/`.

---

## 4. Windows 11 Host Hardware Calculations & Global `.wslconfig`

Global WSL2 virtual machine settings are controlled by `C:\Users\<your-username>\.wslconfig` on the Windows host.

### Host Physical Memory Calculation Formula

Allocating insufficient RAM causes Linux Out-Of-Memory (OOM) kills during heavy AI indexing or 3-node container deployments. Conversely, over-allocating starves Windows 11 host processes.

The optimal RAM allocation matrix for Windows 11 hosts:

| Host Physical RAM | Recommended WSL2 Memory Allocation | Host RAM Reserved for Windows |
|---|---|---|
| **16 GB** | **10 GB** (`memory=10GB`) | 6 GB |
| **32 GB** | **22 GB** (`memory=22GB`) | 10 GB |
| **64 GB** | **48 GB** (`memory=48GB`) | 16 GB |
| **128 GB+** | **96 GB** (`memory=96GB`) | 32 GB+ |

### CPU Thread Allocation

Set `processors` to match the total logical thread count of your Windows host (e.g., 8, 16, 20, or 32 threads). Parallel tools like `ripgrep`, build compilers, and local embedding generators scale linearly across logical vCPUs.

### Networking Modes: NAT vs. Mirrored

WSL2 supports two primary networking modes:

1. **NAT Mode (`networkingMode=nat`) [Project Default]**:
   - Default hypervisor virtual bridge.
   - Preserves container port bindings for rootless PodmanQuadlet container stacks (such as Elasticsearch, Kibana, Fleet Server, Gitea, SemaphoreUI).

2. **Mirrored Mode (`networkingMode=mirrored`)**:
   - Shares host interfaces directly.
   - Ideal for bidirectional localhost access between Windows IDEs (VS Code / JetBrains) and AI CLI agents (Claude Code / Gemini CLI).
   - Enables DNS tunneling (`dnsTunneling=true`) and automatic proxy inheritance (`autoProxy=true`).
   - ⚠️ **Container Warning:** Mirrored networking mode can interfere with container port bindings in Podman.

### Optimized `.wslconfig` Template

```ini
# C:\Users\<your-username>\.wslconfig
[wsl2]
# Calculated for 64 GB host RAM (adjust based on formula above)
memory=48GB
processors=20
swap=16GB
networkingMode=nat
dnsTunneling=true
autoProxy=true

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
```

To apply `.wslconfig` changes, execute in PowerShell / CMD:

```powershell
wsl.exe --shutdown
```

---

## 5. Per-Distribution Configuration (`/etc/wsl.conf`)

Inside your AlmaLinux 10 or Ubuntu 26.04 LTS distribution, edit `/etc/wsl.conf`:

```ini
# /etc/wsl.conf
[boot]
systemd=true

[automount]
enabled=true
options=metadata,umask=22,fmask=11

[network]
generateHosts=true
generateResolvConf=true

[interop]
enabled=true
appendWindowsPath=true

[gpu]
enabled=true

[time]
useWindowsTimezone=true
```

### Explanation of Key Directives:

* `systemd=true`: Mandatory for running user systemd Quadlet services and background AI daemons.
* `options=metadata,umask=22,fmask=11`: Ensures proper Linux permission metadata when interacting with mounted drives.
* `appendWindowsPath=true`: Allows launching Windows tools (`code .`, `explorer.exe .`) while preserving Linux path priority.

---

## 6. Kernel and System Limits Optimization

Large AI projects, language servers, and multi-node Podman clusters consume high numbers of inotify file watchers and file descriptors.

### Inotify File Watches

Increase `fs.inotify.max_user_watches` from the default `8192` to `524288`:

```bash
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Elasticsearch Kernel Map Limits

Elasticsearch requires `vm.max_map_count` to be at least `262144`:

```bash
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Open File Descriptors (`limits.conf`)

Set soft and hard open file limits to `65535` in `/etc/security/limits.conf`:

```ini
*  soft  nofile  65535
*  hard  nofile  65535
```

---

## 7. GPU Acceleration & CUDA Passthrough

WSL2 supports native NVIDIA CUDA passthrough without installing NVIDIA display drivers inside Linux.

### Setup Instructions

1. Install the latest Windows NVIDIA display driver on the host Windows 11 system.
2. Ensure `[gpu] enabled=true` is set in `/etc/wsl.conf`.
3. Verify GPU availability inside WSL2:

   ```bash
   nvidia-smi
   ```

4. Supports PyTorch, TensorFlow, DirectML, and local LLM runners (Ollama / vLLM / llama.cpp).

---

## 8. Security & Environment Variable Management

### Protecting API Keys and Credentials

Avoid committing long-lived API keys (`ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`) in shell startup scripts or repository config files.

1. **Untracked Secret File with Strict Permissions (`0600`)**:
   Store credentials in an untracked environment file (e.g. `~/.ai_credentials.env`) protected by strict file permissions:

   ```bash
   touch ~/.ai_credentials.env
   chmod 0600 ~/.ai_credentials.env
   ```

   Add secrets:

   ```bash
   export ANTHROPIC_API_KEY="sk-ant-api03-xxxxxxxxxxxxxxxxxxxxxxxx"
   export GEMINI_API_KEY="AIzaSyxxxxxxxxxxxxxxxxxxxxxxx"
   ```

   Source it dynamically in `~/.bashrc`:

   ```bash
   if [ -f ~/.ai_credentials.env ]; then
       source ~/.ai_credentials.env
   fi
   ```

2. **Secret Manager or Password Manager Integration**:
   Use `pass` or Bitwarden CLI to load keys dynamically:

   ```bash
   export ANTHROPIC_API_KEY=$(pass show ai/anthropic-key)
   ```

3. **Key Rotation & Telemetry Controls**:
   Rotate API keys regularly in your provider console.
   Note that AI client telemetry controls are client-specific:
   * **Claude Code Telemetry:** `export DISABLE_TELEMETRY=1`
   * **Gemini CLI Telemetry:** `export GEMINI_TELEMETRY_ENABLED=false`

   Neither variable disables reporting for both clients simultaneously.

---

## 9. Disk Space Management & VHD Reclamation

WSL2 virtual hard disk files (`.vhdx`) expand dynamically as files are written. The setting `sparseVhd=true` in `.wslconfig` applies to **newly created** distribution VHDs.

### Reclamation & Conversion Workflow

1. Trim unused filesystem blocks inside WSL2:

   ```bash
   sudo fstrim /
   ```

2. Discover the exact `.vhdx` file path in PowerShell:

   ```powershell
   Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Recurse -Filter "ext4.vhdx" | Select-Object FullName
   ```

3. Convert an existing distribution VHD to sparse format (WSL 2.5+):

   ```powershell
   wsl.exe --manage Ubuntu --set-sparse true
   ```

4. Compact the `.vhdx` file manually via PowerShell (Elevated Administrator):

   ```powershell
   wsl.exe --shutdown
   Optimize-VHD -Path "C:\Users\<user>\AppData\Local\Packages\...\ext4.vhdx" -Mode Full
   ```

---

## 10. AI Toolchain & Sandboxing Installation

### On AlmaLinux 10 (RPM)

```bash
sudo dnf install -y epel-release
sudo dnf install -y bubblewrap socat podman python3-pip
```

### On Ubuntu 26.04 LTS (Debian)

```bash
sudo apt-get update
sudo apt-get install -y bubblewrap socat podman python3-pip
```

### Installing AI Agents safely (Pinned & Verified Releases)

Avoid piping unverified remote responses directly to `bash` or `sh`. Download tagged release binaries or verify checksums prior to execution:

```bash
# Download pinned uv release
curl -LsSf -o uv-installer.sh https://astral.sh/uv/install.sh
# Inspect script content / verify signature
sh uv-installer.sh
rm uv-installer.sh

# Install Claude Code Native Binary
curl -fsSL -o claude-install.sh https://claude.ai/install.sh
sh claude-install.sh
rm claude-install.sh
```

---

## 11. Automated Python `uv` Script (`scripts/wsl2_ai_tuning.py`)

To simplify tuning and security audits, run our project's `uv` executable script:

```bash
# Check current system status and calculated metrics (non-privileged)
uv run scripts/wsl2_ai_tuning.py --check

# Apply full tuning and security configurations using explicit uv path for sudo
sudo $(which uv) run scripts/wsl2_ai_tuning.py --apply --mode=nat
```
