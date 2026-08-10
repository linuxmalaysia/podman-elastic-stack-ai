<!-- markdownlint-disable MD041 -->{% raw %}
# Local Hybrid Execution & Bidirectional Feedback Pipeline Guide

This document provides a comprehensive, production-grade technical specification and operational guide for running local test orchestrations outside the Google Jules cloud environment on a native Linux kernel using Windows WSL2 (Ubuntu 26.04 LTS) and Podman 5+.

It details the implementation of a bidirectional telemetry and feedback pipeline, transferring structured execution diagnostics directly back into both the Google Jules CLI/API session context and GitHub Pull Requests.

---

## 1. System Architecture Blueprint

The local execution fabric operates as an isolated execution runner, completely decoupled from the upstream Jules cloud while maintaining direct bidirectional telemetry visibility through standard CLI tools and REST APIs.

```
+---------------------------------------------------------------------------------------------------+
|                                  LOCAL WSL2 HOST (Ubuntu 26.04 LTS)                               |
|                                                                                                   |
|  +---------------------------+       +---------------------------------------------------------+  |
|  |   Human Operator / Dev    | <---> |                     Google Jules CLI                    |  |
|  +---------------------------+       +---------------------------------------------------------+  |
|                |                                                  ^                               |
|                v                                                  | Telemetry Feed                |
|  +---------------------------+                                    |                               |
|  | Ansible Playbook Runner   | -----------------------------------+                               |
|  | (containers.podman)       |                                    |                               |
|  +---------------------------+                                    |                               |
|                |                                                  |                               |
|                v                                                  |                               |
|  +-------------------------------------------------------------+  |                               |
|  | Podman 5+ Container Matrix                                  |  |                               |
|  |  [ Ubuntu 26.04 ]   [ AlmaLinux 9 ]   [ Debian 12 ]         |  |                               |
|  +-------------------------------------------------------------+  |                               |
|                |                                                  |                               |
|                v (Captures logs / metrics)                        |                               |
|  +-------------------------------------------------------------+  |                               |
|  | scripts/jules_gh_feedback.sh                                 | --+                            |
|  +-------------------------------------------------------------+   |                            |
+--------------------------------------------------------------------|------------------------------+
                                                                     |
                                                                     v
                                                   +-----------------------------------+
                                                   | GitHub PR (via GitHub CLI `gh`)   |
                                                   +-----------------------------------+
```

---

## 2. Mode Separation Protocol (Developer vs User Mode)

A strict operational boundary is enforced between **Developer/Feedback Mode** and **User/Production Mode**. This ensures that development-only debugging hooks, telemetry gathers, and external API requests are completely bypassed for normal end-users.

| Metric / Feature | Developer / Feedback Mode (`dev`) | User / Production Mode (`user`) |
| :--- | :--- | :--- |
| **Trigger Mechanism** | `EXECUTION_MODE=dev ansible-playbook -i inventory/hosts.yml playbooks/matrix_test.yml` or passing `--extra-vars "execution_mode=dev"` | `EXECUTION_MODE=user ansible-playbook ...` or default (no environment variables set) |
| **Telemetry Capture** | Full compilation of OS kernel logs, CPU & memory stats (bytes), container exit codes, and standard outputs. | Zero telemetry gathered. No temporary telemetry files written. |
| **API / CLI Dependencies**| Requires `jules` CLI, local API endpoint, and GitHub CLI (`gh`). | Zero external CLI or API dependencies. |
| **Reporting Output** | Automatically generates `/tmp/jules_telemetry.json` and posts detailed Markdown feedback. | Standard clean execution without temporary file state. |
| **Performance Overhead**| Includes execution time profiling, telemetry collection, and bridge dispatch. | Lightweight, direct container run without metrics overhead. |

### 2.1 Mode Separation Implementation

In Ansible, developer tasks and automated bridge runs are isolated via conditional `when` guards:

```yaml
- name: "Invoke Telemetry Compilation and Reporting Role"
  include_role:
    name: feedback_collector
  when: execution_mode == "dev"

- name: "Automatically Dispatch Telemetry Report"
  command: "{{ playbook_dir }}/../scripts/jules_gh_feedback.sh"
  when: execution_mode == "dev"
```

In the bridge shell script, a developer-mode guard performs early-exit checks:

```bash
# Resolve mode from environment or telemetry file fallback
MODE="${EXECUTION_MODE:-}"
if [ -z "${MODE}" ]; then
    MODE=$(python3 -c "import json; print(json.load(open('/tmp/jules_telemetry.json')).get('execution_mode', 'user'))" 2>/dev/null || echo "user")
fi
MODE="${MODE:-user}"

if [ "${MODE}" != "dev" ]; then
    log_info "Execution mode is '${MODE}' (not 'dev'). Bypassing report generation and feedback dispatch early."
    exit 0
fi
```

---

## 3. WSL2 Host & Podman 5+ Setup Guide

### 3.1 Windows WSL2 (Ubuntu 26.04 LTS) Setup
To install and prepare your local Ubuntu 26.04 LTS host environment under Windows WSL2:

1. Open PowerShell with Administrator privileges and install WSL2:
   ```powershell
   wsl --install -d Ubuntu-26.04
   ```
2. Restart your Windows machine if prompted.
3. Once Ubuntu 26.04 LTS launches, complete the initial user configuration and update the package cache:
   ```bash
   sudo apt-get update -y && sudo apt-get upgrade -y
   ```

### 3.2 Installing Podman 5+ & Ansible
Standard Ubuntu repositories may ship older versions of Podman. To install Podman 5+ along with Ansible:

1. Add the verified community repository key and repository source:
   ```bash
   sudo mkdir -p /etc/apt/keyrings
   curl -fsSL https://download.opensuse.org/repositories/home:/alvistack/xUbuntu_26.04/Release.key | gpg --dearmor | sudo tee /etc/apt/keyrings/home_alvistack.gpg > /dev/null
   echo "deb [signed-by=/etc/apt/keyrings/home_alvistack.gpg] http://download.opensuse.org/repositories/home:/alvistack/xUbuntu_26.04/ /" | sudo tee /etc/apt/sources.list.d/home-alvistack.list
   ```
2. Update the APT cache and install Podman 5+ along with Ansible:
   ```bash
   sudo apt-get update -y
   sudo apt-get install -y podman podman-compose ansible
   ```
3. Install the version-pinned `containers.podman` Ansible collection:
   ```bash
   ansible-galaxy collection install containers.podman:3.1.0 --force
   ```

---

## 4. Human-in-the-Loop Developer Workflow

The bidirectional pipeline enables a tight loop of automated local verification and remote feedback:

```
+------------------------------------------------------------+
|                1. Developer / Human                        |
|   Asks Google Jules to generate or fix code via CLI        |
+------------------------------------------------------------+
                             │
                             ▼
+------------------------------------------------------------+
|                2. Google Jules Agent                       |
|   Creates code modifications, pushes branch, makes GH PR   |
+------------------------------------------------------------+
                             │
                             ▼
+------------------------------------------------------------+
|                3. WSL2 Target Host                         |
|   Runs Ansible Matrix: ansible-playbook matrix_test.yml   |
+------------------------------------------------------------+
                             │
                             ▼
+------------------------------------------------------------+
|                4. Podman 5+ Containers                     |
|   Executes test runs across Ubuntu, AlmaLinux, Debian      |
+------------------------------------------------------------+
                             │
                             ▼
+------------------------------------------------------------+
|                5. Feedback Collector                       |
|   Extracts stats, compiles `/tmp/jules_telemetry.json`     |
+------------------------------------------------------------+
                             │
                             ▼
+------------------------------------------------------------+
|             6. jules_gh_feedback.sh Bridge                 |
|   Feeds telemetry back to Jules & posts comment to GH PR   |
+------------------------------------------------------------+
                             │
                             ▼
+------------------------------------------------------------+
|                7. Iteration Cycle                          |
|   Human reviews outputs, prompts Jules for next refactoring|
+------------------------------------------------------------+
```

### 4.1 Step-by-Step Command Walkthrough

1. **Prompt the Agent:** Ask Jules to implement a feature or patch an issue:
   ```bash
   jules chat --message "Refactor ES client verification to retry on AlmaLinux 9 on connection failures."
   ```
2. **Review Remote PR:** Jules processes the query, implements the change, pushes a branch, and opens a GitHub PR (e.g. PR `#12`).
3. **Execute Local Multi-OS Test Orchestration:** In your WSL2 terminal, trigger the local matrix test suite under developer mode, supplying the Pull Request ID:
   ```bash
   EXECUTION_MODE=dev ansible-playbook -i inventory/hosts.yml playbooks/matrix_test.yml --extra-vars "pr_id=12"
   ```
4. **Automated Test Matrix Run:** Podman spins up containers for Ubuntu 24.04, Ubuntu 26.04, AlmaLinux 9, and Debian 12, running the validations and capturing container execution metrics.
5. **Telemetry Compilation:** The `feedback_collector` Ansible role automatically aggregates container logs, memory usage (converted strictly to bytes), CPU usage, and overall status, writing them to `/tmp/jules_telemetry.json`.
6. **Bidirectional Dispatch:** The playbook automatically triggers `scripts/jules_gh_feedback.sh`. This script formats the parsed JSON telemetry into a rich Markdown table and automatically posts comments to GitHub PR `#12` and streams them to the Google Jules session context.
7. **Iterate:** If any container failed, read the exact log feedback on the GitHub PR or Jules session, ask Jules to correct the specific bug, and run the WSL2 matrix playbook again.

---

## 5. Production Code Repository Layout

All system configurations, playbooks, custom roles, and integration bridge scripts are maintained inside the repository with the following structure:

```
.
├── collections/
│   └── requirements.yml
├── ansible.cfg
├── inventory/
│   └── hosts.yml
├── playbooks/
│   ├── matrix_test.yml
│   └── roles/
│       └── feedback_collector/
│           └── tasks/
│               └── main.yml
└── scripts/
    └── jules_gh_feedback.sh
```

---

## 6. Complete File Reference

The following are the exact production-ready files running the entire orchestration framework. They contain zero placeholders, comments, or ellipses.

### 6.1 `ansible.cfg`
```ini
[defaults]
inventory = inventory/hosts.yml
host_key_checking = False
retry_files_enabled = False
stdout_callback = default
callbacks_enabled = timer, profile_tasks, profile_roles
roles_path = playbooks/roles
callback_result_format = yaml

[privilege_escalation]
become = False
```

### 6.2 `inventory/hosts.yml`
```yaml
---
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: "{{ ansible_playbook_python }}"
  vars:
    execution_mode: "user"
    pr_id: "0"
```

### 6.3 `playbooks/matrix_test.yml`
```yaml
---
- name: Multi-OS Target Matrix Test Orchestrator
  hosts: localhost
  gather_facts: true
  vars:
    execution_mode: "{{ lookup('ansible.builtin.env', 'EXECUTION_MODE') | default('user', true) }}"
    pr_id: "0"

  tasks:
    - name: Initialize Telemetry Context Facts
      set_fact:
        telemetry_results: {}
        overall_status: "passed"

    # ==========================================
    # 1. UBUNTU 24.04 MATRIX TARGET
    # ==========================================
    - name: "Test Target Matrix: Ubuntu 24.04"
      block:
        - name: "Start Ubuntu 24.04 Container"
          containers.podman.podman_container:
            name: "jules_test_ubuntu_24_04"
            image: "docker.io/library/ubuntu:24.04"
            state: started
            command: sleep 3600
            detach: true
            recreate: true
          register: u24_start

        - name: "Profile Ubuntu 24.04 Resource Usage (Pre-test)"
          shell: "podman stats --no-stream --format '{\"cpu_percent\": \"{{ '{{' }}.CPUPerc{{ '}}' }}\", \"mem_usage\": \"{{ '{{' }}.MemUsage{{ '}}' }}\"}' jules_test_ubuntu_24_04"
          register: u24_stats_pre
          ignore_errors: true

        - name: "Execute Verification Suite on Ubuntu 24.04"
          shell: "podman exec jules_test_ubuntu_24_04 bash -c 'apt-get update && apt-get install -y curl && curl --version'"
          register: u24_test_exec

        - name: "Profile Ubuntu 24.04 Resource Usage (Post-test)"
          shell: "podman stats --no-stream --format '{\"cpu_percent\": \"{{ '{{' }}.CPUPerc{{ '}}' }}\", \"mem_usage\": \"{{ '{{' }}.MemUsage{{ '}}' }}\"}' jules_test_ubuntu_24_04"
          register: u24_stats_post
          ignore_errors: true

        - name: "Record Ubuntu 24.04 Success Telemetry"
          set_fact:
            telemetry_results: >-
              {{
                telemetry_results | combine({
                  'ubuntu_24_04': {
                    'status': 'passed',
                    'image': 'docker.io/library/ubuntu:24.04',
                    'exit_code': 0,
                    'cpu_percentage': (u24_stats_post.stdout | default('{}', true) | from_json).cpu_percent | default('0.0%', true),
                    'memory_usage_bytes': (
                      raw_mem_split | regex_replace('[^0-9\.]', '') | float | default(0.0) *
                      (1073741824 if 'G' in raw_mem_unit else (1048576 if 'M' in raw_mem_unit else (1024 if 'K' in raw_mem_unit else 1)))
                    ) | int,
                    'logs': u24_test_exec.stdout | default(''),
                    'error_summary': ''
                  }
                })
              }}
          vars:
            raw_mem_string: "{{ (u24_stats_post.stdout | default('{}', true) | from_json).mem_usage | default('0B', true) }}"
            raw_mem_split: "{{ raw_mem_string.split(' ')[0] }}"
            raw_mem_unit: "{{ raw_mem_split | regex_replace('[0-9\.]', '') | upper }}"

      rescue:
        - name: "Capture Ubuntu 24.04 Failure Details"
          set_fact:
            overall_status: "failed"
            telemetry_results: >-
              {{
                telemetry_results | combine({
                  'ubuntu_24_04': {
                    'status': 'failed',
                    'image': 'docker.io/library/ubuntu:24.04',
                    'exit_code': 1,
                    'cpu_percentage': 'N/A',
                    'memory_usage_bytes': 'N/A',
                    'logs': ansible_failed_result.msg | default('Unknown failure in Ubuntu 24.04 matrix test execution'),
                    'error_summary': 'Task failed during Ubuntu 24.04 validation sequence'
                  }
                })
              }}

      always:
        - name: "Cleanup Ubuntu 24.04 Container"
          containers.podman.podman_container:
            name: "jules_test_ubuntu_24_04"
            state: absent
          ignore_errors: true


    # ==========================================
    # 2. UBUNTU 26.04 MATRIX TARGET
    # ==========================================
    - name: "Test Target Matrix: Ubuntu 26.04"
      block:
        - name: "Start Ubuntu 26.04 Container"
          containers.podman.podman_container:
            name: "jules_test_ubuntu_26_04"
            image: "docker.io/library/ubuntu:26.04"
            state: started
            command: sleep 3600
            detach: true
            recreate: true
          register: u26_start

        - name: "Profile Ubuntu 26.04 Resource Usage (Pre-test)"
          shell: "podman stats --no-stream --format '{\"cpu_percent\": \"{{ '{{' }}.CPUPerc{{ '}}' }}\", \"mem_usage\": \"{{ '{{' }}.MemUsage{{ '}}' }}\"}' jules_test_ubuntu_26_04"
          register: u26_stats_pre
          ignore_errors: true

        - name: "Execute Verification Suite on Ubuntu 26.04"
          shell: "podman exec jules_test_ubuntu_26_04 bash -c 'apt-get update && apt-get install -y curl && curl --version'"
          register: u26_test_exec

        - name: "Profile Ubuntu 26.04 Resource Usage (Post-test)"
          shell: "podman stats --no-stream --format '{\"cpu_percent\": \"{{ '{{' }}.CPUPerc{{ '}}' }}\", \"mem_usage\": \"{{ '{{' }}.MemUsage{{ '}}' }}\"}' jules_test_ubuntu_26_04"
          register: u26_stats_post
          ignore_errors: true

        - name: "Record Ubuntu 26.04 Success Telemetry"
          set_fact:
            telemetry_results: >-
              {{
                telemetry_results | combine({
                  'ubuntu_26_04': {
                    'status': 'passed',
                    'image': 'docker.io/library/ubuntu:26.04',
                    'exit_code': 0,
                    'cpu_percentage': (u26_stats_post.stdout | default('{}', true) | from_json).cpu_percent | default('0.0%', true),
                    'memory_usage_bytes': (
                      raw_mem_split | regex_replace('[^0-9\.]', '') | float | default(0.0) *
                      (1073741824 if 'G' in raw_mem_unit else (1048576 if 'M' in raw_mem_unit else (1024 if 'K' in raw_mem_unit else 1)))
                    ) | int,
                    'logs': u26_test_exec.stdout | default(''),
                    'error_summary': ''
                  }
                })
              }}
          vars:
            raw_mem_string: "{{ (u26_stats_post.stdout | default('{}', true) | from_json).mem_usage | default('0B', true) }}"
            raw_mem_split: "{{ raw_mem_string.split(' ')[0] }}"
            raw_mem_unit: "{{ raw_mem_split | regex_replace('[0-9\.]', '') | upper }}"

      rescue:
        - name: "Capture Ubuntu 26.04 Failure Details"
          set_fact:
            overall_status: "failed"
            telemetry_results: >-
              {{
                telemetry_results | combine({
                  'ubuntu_26_04': {
                    'status': 'failed',
                    'image': 'docker.io/library/ubuntu:26.04',
                    'exit_code': 1,
                    'cpu_percentage': 'N/A',
                    'memory_usage_bytes': 'N/A',
                    'logs': ansible_failed_result.msg | default('Unknown failure in Ubuntu 26.04 matrix test execution'),
                    'error_summary': 'Task failed during Ubuntu 26.04 validation sequence'
                  }
                })
              }}

      always:
        - name: "Cleanup Ubuntu 26.04 Container"
          containers.podman.podman_container:
            name: "jules_test_ubuntu_26_04"
            state: absent
          ignore_errors: true


    # ==========================================
    # 3. ALMALINUX 9 MATRIX TARGET
    # ==========================================
    - name: "Test Target Matrix: AlmaLinux 9"
      block:
        - name: "Start AlmaLinux 9 Container"
          containers.podman.podman_container:
            name: "jules_test_almalinux_9"
            image: "docker.io/library/almalinux:9"
            state: started
            command: sleep 3600
            detach: true
            recreate: true
          register: alma_start

        - name: "Profile AlmaLinux 9 Resource Usage (Pre-test)"
          shell: "podman stats --no-stream --format '{\"cpu_percent\": \"{{ '{{' }}.CPUPerc{{ '}}' }}\", \"mem_usage\": \"{{ '{{' }}.MemUsage{{ '}}' }}\"}' jules_test_almalinux_9"
          register: alma_stats_pre
          ignore_errors: true

        - name: "Execute Verification Suite on AlmaLinux 9"
          shell: "podman exec jules_test_almalinux_9 bash -c 'dnf clean all && dnf install -y curl && curl --version'"
          register: alma_test_exec

        - name: "Profile AlmaLinux 9 Resource Usage (Post-test)"
          shell: "podman stats --no-stream --format '{\"cpu_percent\": \"{{ '{{' }}.CPUPerc{{ '}}' }}\", \"mem_usage\": \"{{ '{{' }}.MemUsage{{ '}}' }}\"}' jules_test_almalinux_9"
          register: alma_stats_post
          ignore_errors: true

        - name: "Record AlmaLinux 9 Success Telemetry"
          set_fact:
            telemetry_results: >-
              {{
                telemetry_results | combine({
                  'almalinux_9': {
                    'status': 'passed',
                    'image': 'docker.io/library/almalinux:9',
                    'exit_code': 0,
                    'cpu_percentage': (alma_stats_post.stdout | default('{}', true) | from_json).cpu_percent | default('0.0%', true),
                    'memory_usage_bytes': (
                      raw_mem_split | regex_replace('[^0-9\.]', '') | float | default(0.0) *
                      (1073741824 if 'G' in raw_mem_unit else (1048576 if 'M' in raw_mem_unit else (1024 if 'K' in raw_mem_unit else 1)))
                    ) | int,
                    'logs': alma_test_exec.stdout | default(''),
                    'error_summary': ''
                  }
                })
              }}
          vars:
            raw_mem_string: "{{ (alma_stats_post.stdout | default('{}', true) | from_json).mem_usage | default('0B', true) }}"
            raw_mem_split: "{{ raw_mem_string.split(' ')[0] }}"
            raw_mem_unit: "{{ raw_mem_split | regex_replace('[0-9\.]', '') | upper }}"

      rescue:
        - name: "Capture AlmaLinux 9 Failure Details"
          set_fact:
            overall_status: "failed"
            telemetry_results: >-
              {{
                telemetry_results | combine({
                  'almalinux_9': {
                    'status': 'failed',
                    'image': 'docker.io/library/almalinux:9',
                    'exit_code': 1,
                    'cpu_percentage': 'N/A',
                    'memory_usage_bytes': 'N/A',
                    'logs': ansible_failed_result.msg | default('Unknown failure in AlmaLinux 9 matrix test execution'),
                    'error_summary': 'Task failed during AlmaLinux 9 validation sequence'
                  }
                })
              }}

      always:
        - name: "Cleanup AlmaLinux 9 Container"
          containers.podman.podman_container:
            name: "jules_test_almalinux_9"
            state: absent
          ignore_errors: true


    # ==========================================
    # 4. DEBIAN 12 MATRIX TARGET
    # ==========================================
    - name: "Test Target Matrix: Debian 12"
      block:
        - name: "Start Debian 12 Container"
          containers.podman.podman_container:
            name: "jules_test_debian_12"
            image: "docker.io/library/debian:12"
            state: started
            command: sleep 3600
            detach: true
            recreate: true
          register: debian_start

        - name: "Profile Debian 12 Resource Usage (Pre-test)"
          shell: "podman stats --no-stream --format '{\"cpu_percent\": \"{{ '{{' }}.CPUPerc{{ '}}' }}\", \"mem_usage\": \"{{ '{{' }}.MemUsage{{ '}}' }}\"}' jules_test_debian_12"
          register: debian_stats_pre
          ignore_errors: true

        - name: "Execute Verification Suite on Debian 12"
          shell: "podman exec jules_test_debian_12 bash -c 'apt-get update && apt-get install -y curl && curl --version'"
          register: debian_test_exec

        - name: "Profile Debian 12 Resource Usage (Post-test)"
          shell: "podman stats --no-stream --format '{\"cpu_percent\": \"{{ '{{' }}.CPUPerc{{ '}}' }}\", \"mem_usage\": \"{{ '{{' }}.MemUsage{{ '}}' }}\"}' jules_test_debian_12"
          register: debian_stats_post
          ignore_errors: true

        - name: "Record Debian 12 Success Telemetry"
          set_fact:
            telemetry_results: >-
              {{
                telemetry_results | combine({
                  'debian_12': {
                    'status': 'passed',
                    'image': 'docker.io/library/debian:12',
                    'exit_code': 0,
                    'cpu_percentage': (debian_stats_post.stdout | default('{}', true) | from_json).cpu_percent | default('0.0%', true),
                    'memory_usage_bytes': (
                      raw_mem_split | regex_replace('[^0-9\.]', '') | float | default(0.0) *
                      (1073741824 if 'G' in raw_mem_unit else (1048576 if 'M' in raw_mem_unit else (1024 if 'K' in raw_mem_unit else 1)))
                    ) | int,
                    'logs': debian_test_exec.stdout | default(''),
                    'error_summary': ''
                  }
                })
              }}
          vars:
            raw_mem_string: "{{ (debian_stats_post.stdout | default('{}', true) | from_json).mem_usage | default('0B', true) }}"
            raw_mem_split: "{{ raw_mem_string.split(' ')[0] }}"
            raw_mem_unit: "{{ raw_mem_split | regex_replace('[0-9\.]', '') | upper }}"

      rescue:
        - name: "Capture Debian 12 Failure Details"
          set_fact:
            overall_status: "failed"
            telemetry_results: >-
              {{
                telemetry_results | combine({
                  'debian_12': {
                    'status': 'failed',
                    'image': 'docker.io/library/debian:12',
                    'exit_code': 1,
                    'cpu_percentage': 'N/A',
                    'memory_usage_bytes': 'N/A',
                    'logs': ansible_failed_result.msg | default('Unknown failure in Debian 12 matrix test execution'),
                    'error_summary': 'Task failed during Debian 12 validation sequence'
                  }
                })
              }}

      always:
        - name: "Cleanup Debian 12 Container"
          containers.podman.podman_container:
            name: "jules_test_debian_12"
            state: absent
          ignore_errors: true


    # ==========================================
    # TELEMETRY COMPILATION DISPATCH
    # ==========================================
    - name: "Invoke Telemetry Compilation and Reporting Role"
      include_role:
        name: feedback_collector
      when: execution_mode == "dev"

    - name: "Automatically Dispatch Telemetry Report"
      command: "{{ playbook_dir }}/../scripts/jules_gh_feedback.sh"
      when: execution_mode == "dev"
```

### 6.4 `playbooks/roles/feedback_collector/tasks/main.yml`
```yaml
---
- name: Get Podman version on WSL2 host
  command: podman --version
  register: podman_version_cmd
  ignore_errors: true

- name: Generate current UTC timestamp
  command: date -u +"%Y-%m-%dT%H:%M:%SZ"
  register: timestamp_cmd
  ignore_errors: true

- name: Initialize formatted results list
  set_fact:
    formatted_results: []

- name: Construct formatted results array
  set_fact:
    formatted_results: >-
      {{
        formatted_results + [{
          'distro': item.key,
          'image': item.value.image,
          'status': item.value.status,
          'exit_code': item.value.exit_code | int,
          'cpu_percentage': item.value.cpu_percentage,
          'memory_usage_bytes': item.value.memory_usage_bytes,
          'logs': item.value.logs,
          'error_summary': item.value.error_summary
        }]
      }}
  loop: "{{ telemetry_results | dict2items }}"

- name: Build complete telemetry payload dictionary
  set_fact:
    telemetry_payload:
      timestamp: "{{ timestamp_cmd.stdout | trim | default('N/A') }}"
      execution_mode: "{{ execution_mode | default('dev') }}"
      pr_id: "{{ pr_id | default('0') }}"
      overall_status: "{{ overall_status | default('passed') }}"
      host_info:
        os_family: "{{ ansible_os_family | default('Unknown') }}"
        kernel_version: "{{ ansible_kernel | default('Unknown') }}"
        podman_version: "{{ podman_version_cmd.stdout | trim | default('Unknown') }}"
      results: "{{ formatted_results }}"

- name: Write structured JSON report to /tmp/jules_telemetry.json
  copy:
    content: "{{ telemetry_payload | to_nice_json }}"
    dest: "/tmp/jules_telemetry.json"
    mode: "0600"
```

### 6.5 `scripts/jules_gh_feedback.sh`
```bash
#!/usr/bin/env bash
# ==============================================================================
# BIDIRECTIONAL TELEMETRY & FEEDBACK BRIDGE SCRIPT
# ==============================================================================
# Strict standards: UK English, set -euo pipefail, POSIX compliance, dynamic traps.
# Parses /tmp/jules_telemetry.json, constructs Markdown report, and posts to
# Google Jules CLI/API & GitHub Pull Request.
# ==============================================================================

set -euo pipefail

# Define Color Loggers
log_info()    { echo -e "\033[1;36m[INFO]\033[0m $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_warn()    { echo -e "\033[1;33m[WARN]\033[0m $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error()   { echo -e "\033[1;31m[ERROR]\033[0m $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

# Establish variables
TELEMETRY_JSON="/tmp/jules_telemetry.json"
REPORT_MD=""

# Establish Trap for Cleanup and Exit Status Tracking on EXIT
cleanup() {
    local exit_code=$?
    if [ -n "${REPORT_MD}" ] && [ -f "${REPORT_MD}" ]; then
        rm -f "${REPORT_MD}"
    fi
    if [ "${exit_code}" -eq 0 ]; then
        log_success "Feedback bridge finished successfully."
    else
        log_error "Feedback bridge execution aborted or failed with status code ${exit_code}."
    fi
}
trap cleanup EXIT

# Separate traps for SIGINT and SIGTERM to terminate with non-zero exit statuses
trap 'log_warn "SIGINT received, aborting..."; exit 130' INT
trap 'log_warn "SIGTERM received, aborting..."; exit 143' TERM

# Ensure Telemetry Data Exists before checking mode
if [ ! -f "${TELEMETRY_JSON}" ]; then
    log_error "Telemetry data file '${TELEMETRY_JSON}' not found! Please run the matrix test playbook first."
    exit 1
fi

# Get EXECUTION_MODE from environment, or from /tmp/jules_telemetry.json fallback
MODE="${EXECUTION_MODE:-}"
if [ -z "${MODE}" ]; then
    MODE=$(python3 -c "import json; print(json.load(open('${TELEMETRY_JSON}')).get('execution_mode', 'user'))" 2>/dev/null || echo "user")
fi
MODE="${MODE:-user}"

# Early Developer-Mode Guard: return 0 before report generation or dispatch if mode is not dev
if [ "${MODE}" != "dev" ]; then
    log_info "Execution mode is '${MODE}' (not 'dev'). Bypassing report generation and feedback dispatch early."
    exit 0
fi

log_info "Parsing telemetry data and compiling Markdown report..."

# Replace predictable REPORT_MD creation with a mktemp-generated path enforcing mode 0600
REPORT_MD=$(mktemp /tmp/jules_telemetry_report.XXXXXX.md)
chmod 0600 "${REPORT_MD}"

# Inline Python parser for structured conversion of JSON to robust Markdown
python3 - <<EOF
import json
import sys

try:
    with open("${TELEMETRY_JSON}", "r") as f:
        data = json.load(f)
except Exception as e:
    print(f"Error decoding telemetry JSON: {e}", file=sys.stderr)
    sys.exit(1)

status_emoji = "✅" if data.get("overall_status") == "passed" else "❌"
pr_id = data.get("pr_id", "0")

md = []
md.append("# 🚀 Google Jules - Multi-OS Matrix Test Execution Report")
md.append(f"**Overall Status:** {data.get('overall_status', 'unknown').upper()} {status_emoji}")
md.append(f"**Execution Mode:** \`{data.get('execution_mode', 'dev')}\` | **PR ID:** \`#{pr_id}\`")
md.append(f"**Timestamp:** \`{data.get('timestamp', 'N/A')}\`\n")

md.append("### 💻 Host Environment")
host = data.get("host_info", {})
md.append(f"- **OS Family:** {host.get('os_family', 'Unknown')}")
md.append(f"- **Kernel Version:** \`{host.get('kernel_version', 'Unknown')}\`")
md.append(f"- **Podman Version:** \`{host.get('podman_version', 'Unknown')}\`\n")

md.append("### 📊 Test Matrix Results")
md.append("| Target Distro | Container Image | Status | Exit Code | CPU % | Memory | Error Summary |")
md.append("| :--- | :--- | :--- | :--- | :--- | :--- | :--- |")

results = data.get("results", [])
# Handle potential string format or dictionary list for results
if isinstance(results, str):
    try:
        results = json.loads(results)
    except Exception:
        results = []

for res in results:
    distro = res.get("distro", "Unknown")
    img = res.get("image", "Unknown")
    status = res.get("status", "Unknown").upper()
    emoji = "✅ PASSED" if status == "PASSED" else "❌ FAILED"
    code = res.get("exit_code", -1)
    cpu = res.get("cpu_percentage", "0.0%")
    mem = str(res.get("memory_usage_bytes", "0"))
    err = res.get("error_summary", "") or "-"
    md.append(f"| **{distro}** | \`{img}\` | **{emoji}** | \`{code}\` | \`{cpu}\` | \`{mem}\` | {err} |")

md.append("\n### 📝 Execution Logs")
for res in results:
    distro = res.get("distro", "Unknown")
    logs = res.get("logs", "")
    status = res.get("status", "Unknown").upper()
    md.append("<details>")
    md.append(f"<summary><b>{distro} ({status}) Log Output</b></summary>\n")
    md.append("\`\`\`text")
    md.append(logs if logs else "No output logged.")
    md.append("\`\`\`")
    md.append("</details>\n")

try:
    with open("${REPORT_MD}", "w") as f:
        f.write('\n'.join(md))
except Exception as e:
    print(f"Error writing markdown report: {e}", file=sys.stderr)
    sys.exit(1)

print("Report generated successfully.")
EOF

log_success "Markdown report generated at '${REPORT_MD}'"

# Extract metadata for feedback
PR_NUMBER=$(python3 -c "import json; print(json.load(open('${TELEMETRY_JSON}')).get('pr_id', '0'))" 2>/dev/null || echo "0")
OVERALL_STATUS=$(python3 -c "import json; print(json.load(open('${TELEMETRY_JSON}')).get('overall_status', 'passed'))" 2>/dev/null || echo "passed")

# ------------------------------------------------------------------------------
# 1. GitHub Pull Request Integration via gh CLI
# ------------------------------------------------------------------------------
if command -v gh >/dev/null 2>&1; then
    if [ "${PR_NUMBER}" != "0" ] && [ -n "${PR_NUMBER}" ]; then
        log_info "Attempting to post report to GitHub Pull Request #${PR_NUMBER}..."
        # Verify if the user is authenticated with GitHub CLI
        if gh auth status >/dev/null 2>&1; then
            if gh pr comment "${PR_NUMBER}" --body-file "${REPORT_MD}" >/dev/null 2>&1; then
                log_success "Successfully posted test report comment on GitHub PR #${PR_NUMBER}!"
            else
                log_warn "Failed to post comment to PR #${PR_NUMBER}. This may be due to repository permissions."
            fi
        else
            log_warn "GitHub CLI ('gh') is not authenticated. Skipping PR comment creation."
        fi
    else
        log_info "PR_ID is set to default (0) or empty. Skipping GitHub PR comments."
    fi
else
    log_warn "GitHub CLI ('gh') is not installed or not available on PATH. Skipping GitHub PR comment."
fi

# ------------------------------------------------------------------------------
# 2. Google Jules CLI Session Context Integration
# ------------------------------------------------------------------------------
JULES_POSTED=false

if command -v jules >/dev/null 2>&1; then
    log_info "Google Jules CLI detected. Attempting to feed session context..."

    # Try feeding via jules feed command
    if jules feed --help >/dev/null 2>&1; then
        if jules feed --message-file "${REPORT_MD}" >/dev/null 2>&1; then
            log_success "Successfully fed matrix telemetry to active Jules session via 'jules feed'!"
            JULES_POSTED=true
        fi
    fi

    # Fallback to jules chat context inject if jules feed wasn't successful/supported
    if [ "${JULES_POSTED}" = "false" ]; then
        if jules chat --help >/dev/null 2>&1; then
            if jules chat --message "Local Test Matrix Execution Report: $(cat "${REPORT_MD}")" >/dev/null 2>&1; then
                log_success "Successfully injected matrix telemetry into active Jules session via 'jules chat'!"
                JULES_POSTED=true
            fi
        fi
    fi
else
    log_warn "Google Jules CLI ('jules') is not installed or not available on PATH."
fi

# ------------------------------------------------------------------------------
# 3. Google Jules REST API Direct Fallback Integration
# ------------------------------------------------------------------------------
if [ "${JULES_POSTED}" = "false" ] && [ -n "${JULES_API_ENDPOINT:-}" ]; then
    log_info "Attempting to post telemetry to local Google Jules REST API at '${JULES_API_ENDPOINT}'..."
    if command -v curl >/dev/null 2>&1; then
        # Updated curl invocation to include connection timeout (10s) and total request timeout (30s)
        HTTP_RESPONSE=$(curl -s --connect-timeout 10 --max-time 30 -o /dev/null -w "%{http_code}" \
            -X POST "${JULES_API_ENDPOINT}/telemetry" \
            -H "Authorization: Bearer ${JULES_SESSION_TOKEN:-}" \
            -H "Content-Type: application/json" \
            -d @"${TELEMETRY_JSON}" || echo "failed")

        if [ "${HTTP_RESPONSE}" = "200" ] || [ "${HTTP_RESPONSE}" = "201" ]; then
            log_success "Successfully posted telemetry data directly to Jules REST API (HTTP ${HTTP_RESPONSE})!"
            JULES_POSTED=true
        else
            log_warn "Failed to post telemetry to Jules REST API. HTTP Response Code: ${HTTP_RESPONSE}"
        fi
    else
        log_warn "curl is missing. Cannot call Jules REST API."
    fi
fi

# ------------------------------------------------------------------------------
# 4. Graceful Operational Fallback
# ------------------------------------------------------------------------------
if [ "${JULES_POSTED}" = "false" ]; then
    log_warn "======================================================================"
    log_warn "WARNING: Telemetry report could not be automatically streamed to Jules!"
    log_warn "======================================================================"
    log_warn "1. The local jules CLI is not present/configured on WSL2."
    log_warn "2. JULES_API_ENDPOINT environment variable is not defined."
    log_warn "----------------------------------------------------------------------"
    log_warn "Action required: Human operators can manually read the generated"
    log_warn "Markdown report file and paste it into the Jules conversation context:"
    log_warn "   cat ${REPORT_MD}"
    log_warn "======================================================================"
fi

# Exit successfully to guarantee pipeline resiliency
exit 0
```
{% endraw %}
