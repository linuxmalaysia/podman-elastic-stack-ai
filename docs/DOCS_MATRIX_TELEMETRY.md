{% raw %}
# SYSTEM ARCHITECTURE & BLUEPRINT DIRECTIVE: MATRIX TELEMETRY & FEEDBACK PIPELINE

<!-- markdownlint-disable-file MD041 -->

**Author:** Senior Principal Systems & Automation Architect
**Target Environment:** Windows WSL2 (Ubuntu 26.04 LTS Host) + Podman 5+ Container Engine
**Toolchain:** Ansible 2.16+, Bash (POSIX-compliant), Google Jules CLI / API, GitHub CLI (`gh`), Git

---

## 1. Architectural Architecture & Mode Separation Protocol

The telemetry and feedback pipeline operates under a strict segregation model. This ensures that debugging hooks, API authentication keys, and performance profiling mechanisms are physically and logically isolated, completely preventing leakage or overhead in user-facing production environments.

### 1.1 Separation Modes

| Metric / Feature | Developer / Feedback Mode (`dev`) | User / Production Mode (`user`) |
| :--- | :--- | :--- |
| **Trigger Mechanism** | `EXECUTION_MODE=dev ansible-playbook -i inventory/hosts.yml playbooks/matrix_test.yml` or `ansible-playbook -i inventory/hosts.yml playbooks/matrix_test.yml --extra-vars "execution_mode=dev"` | `EXECUTION_MODE=user ansible-playbook -i inventory/hosts.yml playbooks/matrix_test.yml` or `ansible-playbook -i inventory/hosts.yml playbooks/matrix_test.yml` |
| **Telemetry Capture** | Full (CPU, Memory, dmesg, container logs, exit codes) | Zero telemetry gathered, no diagnostic files written |
| **API / CLI Dependencies** | Requires `jules` CLI, local API endpoint, and `gh` CLI | Zero external CLI or API dependencies |
| **Reporting Output** | Generated `/tmp/jules_telemetry.json` and Markdown PR comments | Standard clean execution without temporary file state |
| **Performance Overhead** | Profiling and logging tasks executed | Lightweight execution path with direct container spin-ups |

### 1.2 Isolation Implementation

Ansible playbooks implement this boundary dynamically via variable-driven conditional execution:

```yaml
- name: Execute developer telemetry compilation
  include_role:
    name: feedback_collector
  when: execution_mode == "dev"
```

In the bridge bash scripts, standard checks are performed prior to running any external tooling:
- **Mode Source Resolution**: The execution mode is resolved consistently. The bridge script first checks the `EXECUTION_MODE` environment variable. If empty, it extracts the `execution_mode` attribute from `/tmp/jules_telemetry.json`. If still unresolved, it defaults to `user`.
- **Feedback Dispatch Requirement**: Feedback dispatch must be run in developer mode. If the resolved mode is not `dev`, the bridge script aborts report generation and feedback dispatch early, exiting with status `0` to avoid disrupting standard pipelines:

```bash
if [ "${MODE}" != "dev" ]; then
    log_info "Execution mode is '${MODE}' (not 'dev'). Bypassing report generation and feedback dispatch early."
    exit 0
fi
```

This prevents external API requests or credential checking during production deployments, preserving security, minimizing CPU/network overhead, and ensuring local privacy.

---

## 2. Podman 5+ Multi-OS Matrix Orchestration (`ansible/`)

The matrix orchestration engine automates parallel test runs across multi-distro targets. Using Podman 5+ containerization, it mounts local workspace volumes, runs validation checks, and profiles container system states.

### 2.1 Multi-OS Distribution Targets

* **Ubuntu 24.04 LTS (Noble Numbat)** (`docker.io/library/ubuntu:24.04`)
* **Ubuntu 26.04 LTS (Resolute Raccoon)** (`docker.io/library/ubuntu:26.04`)
* **AlmaLinux 9 (RHEL Compatible)** (`docker.io/library/almalinux:9`)
* **Debian 12 (Bookworm)** (`docker.io/library/debian:12`)

### 2.2 Dependencies

This playbook uses the `containers.podman` collection to orchestrate Podman container targets. The version-pinned dependency is declared in `collections/requirements.yml` and must be installed prior to running the playbook using the following command:

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

### 2.3 Error Management Pattern (`block/rescue/always`)

To guarantee telemetry capture even in severe failure scenarios, tasks are structured inside an Ansible `block/rescue/always` framework:

```yaml
- name: Multi-OS Target Execution Block
  block:
    - name: Orchestrate Podman containers and run tests
      include_tasks: run_container_tests.yml
  rescue:
    - name: Flag execution failure status
      set_fact:
        matrix_execution_status: "failed"
        failure_error_message: "{{ ansible_failed_result.msg | default('Unknown execution error') }}"
  always:
    - name: Gather metrics and compile telemetry report
      include_role:
        name: feedback_collector
```

### 2.4 Telemetry Schema (`/tmp/jules_telemetry.json`)

The `feedback_collector` role compiles diagnostic facts into a structured JSON schema saved locally at `/tmp/jules_telemetry.json`. This schema contains the following details:

```json
{
  "timestamp": "2025-04-10T14:30:00Z",
  "execution_mode": "dev",
  "pr_id": "123",
  "overall_status": "failed",
  "host_info": {
    "os_family": "Debian",
    "kernel_version": "6.8.0-1004-wsl",
    "podman_version": "5.0.3"
  },
  "results": [
    {
      "distro": "ubuntu_24_04",
      "image": "docker.io/library/ubuntu:24.04",
      "status": "passed",
      "exit_code": 0,
      "cpu_percentage": "1.2",
      "memory_usage_bytes": 12451840,
      "logs": "Starting test runner...\nAll checks passed.\n",
      "error_summary": ""
    },
    {
      "distro": "almalinux_9",
      "image": "docker.io/library/almalinux:9",
      "status": "failed",
      "exit_code": 1,
      "cpu_percentage": "4.5",
      "memory_usage_bytes": 48293120,
      "logs": "Starting test runner...\nError: Connection to Elasticsearch failed.\n",
      "error_summary": "Connection to Elasticsearch timed out after 30 seconds."
    }
  ]
}
```

---

## 3. Bidirectional Jules CLI & GitHub PR Bridge Script (`scripts/jules_gh_feedback.sh`)

The bridge script is an idempotent Bash runner responsible for parsing the JSON telemetry, formulating rich Markdown reports, and streaming diagnostic data.

### 3.1 Idempotence and Error Resilience
* **Strict POSIX and Bash Options:** Runs with `set -euo pipefail` to abort immediately on uncaught errors or unbound variables.
* **Signal Traps:** Traps `EXIT` to clean up mktemp-generated files and logs. Traps `SIGINT` and `SIGTERM` separately to log termination warnings and exit with standard non-zero codes (e.g., `130`, `143`), automatically triggering the `EXIT` cleanup logic.
* **Dynamic Logging Functions:** Custom logger prints timestamped outputs colored by message severity:
  - Green `[SUCCESS]`
  - Cyan `[INFO]`
  - Yellow `[WARN]`
  - Red `[ERROR]`

### 3.2 Feedback Channels
1. **Google Jules CLI Integration:** Invokes `jules feed` or `jules chat` command pipelines to register the telemetry output directly back into the active LLM context.
2. **GitHub Pull Request Integration:** Uses `gh pr comment` to comment directly on the specific Pull Request, keeping human operators informed in real-time.
3. **Graceful Fallbacks:** If the CLI tools (`jules` or `gh`) are not logged in or missing tokens, the script logs warning messages, saves the markdown payload to a private, non-predictable mktemp-generated file under `/tmp` with secure mode `0600` for manual action, and exits cleanly with `0` to prevent breaking developers' local pipelines.

---

## 4. Human-in-the-Loop Developer Workflow Diagram & Operational Guide

### 4.1 Process Flow Diagram

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
|   Extracts stats, compiles `/tmp/jules_telemetry.json`      |
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

### 4.2 Operational Step-by-Step Guide

1. **Trigger Code Generation:**
   Initiate an issue fix or feature addition:
   ```bash
   jules chat --message "Fix connection pooling timeout under AlmaLinux 9 in ansible roles"
   ```
2. **Retrieve Branch and Pull Request:**
   The agent creates a branch and issues a GitHub PR (e.g. PR #12).
3. **Execute Local Multi-OS Test Orchestration:**
   From the WSL2 Ubuntu 26.04 terminal, run the target matrix playbook under developer mode, supplying the Pull Request ID:
   ```bash
   EXECUTION_MODE=dev ansible-playbook -i inventory/hosts.yml playbooks/matrix_test.yml --extra-vars "pr_id=12"
   ```
4. **Automated Feedback Pipeline:**
   The playbook runs tests within isolated container environments. On task completion (regardless of success or failure), the `feedback_collector` compiles `/tmp/jules_telemetry.json` and automatically triggers `scripts/jules_gh_feedback.sh`.
5. **Bridge Dispatch:**
   The `scripts/jules_gh_feedback.sh` script is triggered automatically:
   ```bash
   ./scripts/jules_gh_feedback.sh
   ```
   This formats a detailed Markdown table of system stats, container resource usage in bytes, and error outputs, and posts it directly to GitHub PR #12 and streams it to Google Jules.
6. **Iterate:**
   Read the posted diagnostics, prompt Jules to adjust the code based on exact container failures, and run the matrix again.

---

## 5. Directory Tree & Production-Ready Shell/Ansible Files

### 5.1 Complete File Tree

```
.
├── collections
│   └── requirements.yml
├── ansible.cfg
├── inventory
│   └── hosts.yml
├── playbooks
│   ├── matrix_test.yml
│   └── roles
│       └── feedback_collector
│           └── tasks
│               └── main.yml
└── scripts
    └── jules_gh_feedback.sh
```

---

*This document serves as the master architectural specification for local multi-OS telemetry extraction and bidirectional agent-human orchestration loops.*
{% endraw %}
