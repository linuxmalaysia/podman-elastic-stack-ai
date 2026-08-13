---
okf_version: 0.1
type: documentation
title: "ELASTIC_9_UPGRADE_PLAN.md"
description: "Comprehensive Guide and 2-Week Plan for Upgrading the Podman-based Elastic Stack to Version 9.5.x or Latest."
topics: [elastic, upgrade, planning, migration, podman, ansible]
resource: file:///docs/ELASTIC_9_UPGRADE_PLAN.md
timestamp: 2026-07-12T10:00:00Z
---
{% raw %}

# 🚀 Elastic Stack 9.5.x (or Latest) Upgrade Plan

This master architectural blueprint outlines the comprehensive strategy and 2-week roadmap to migrate our containerised, rootless Elastic Stack deployment from **v8.x** to the next-generation major release **v9.5.x or latest**.

As this project leverages a highly secure, unprivileged **Rootless Podman 5+** and **systemd Quadlet** environment running on hardened **Wolfi Linux** minimal container images, standard upgrade pathways must be tailored specifically to preserve unprivileged socket boundaries, local volume storage permissions, and automated Ansible deployment flows.

---

## 🏛️ 1. Architectural Impact & Sovereign Strategy

Upgrading to a new major version of the Elastic Stack requires rigorous validation of security protocols, API deprecations, cluster coordination limits, and agent schema models. Under our unprivileged execution context, we prioritize the following architectural tenets:

*   **Continuous TLS Enforcement**: Elastic 9.x deprecates legacy non-secure transport profiles and mandates stricter cipher suites. Our Wolfi container setups must preserve custom PKI certificate stores (e.g. `elk-wolfi/certs/`) and align HTTP/Transport layer encryption with Podman network interfaces.
*   **Unprivileged Permission Preservation**: High-range subuids (e.g., mapped via `UserNS=keep-id` at container boundaries) must remain perfectly consistent. When container image tags shift from `9.4.4` to `9.5.x` or latest, local data mounts under `/opt/dsom-persistence/` must not experience permission drift or ownership locking.
*   **Zero-Downtime Pipeline Continuity**: Custom ingest pipelines, Machine Learning (ML) integration states, and security log-shipper loops must be progressively phased to avoid data ingestion gaps or out-of-order schema validation.

---

## 📅 2. The 2-Week Master Upgrade Schedule

```
+--------------------------------------------------------------------------------------------------------+
|                                     PREPARATION PHASE (WEEK 0)                                         |
|  • Upgrade to last 8.x minor (e.g. 8.17.x)       • Run Kibana Upgrade Assistant & resolve warnings     |
|  • Snapshot persistent storage & configurations   • Rebuild/pull 9.5.x hardened Wolfi container images  |
+--------------------------------------------------------------------------------------------------------+
                                                     │
                                                     ▼
+--------------------------------------------------------------------------------------------------------+
|                                           WEEK 1 EXECUTION                                             |
|  1. Upgrade Host OS packages & Podman on cluster hosts (including kernel-level memory tuning).         |
|  2. Perform rolling/cluster upgrade of Elasticsearch (validating cluster health & TLS requirements).   |
|  3. Upgrade Kibana (mapping updated endpoint environment and testing secure connection).              |
|  4. Upgrade Fleet Server containers and roll out upgraded Fleet Integration policies.                  |
|  5. Perform OS updates for the wider Elastic Agent Fleet nodes.                                        |
|  6. Deploy upgraded non-Machine Learning (non-ML) Integrations inside Fleet manager.                   |
+--------------------------------------------------------------------------------------------------------+
                                                     │
                                                     ▼
+--------------------------------------------------------------------------------------------------------+
|                                           WEEK 2 EXECUTION                                             |
|  7. Upgrade Machine Learning (ML) Integrations and verify zero ingestion gaps in ingest pipelines.     |
|  8. Phase out the deployment to high-security Airgapped topologies if required (local image registry).  |
|  9. Finalise agent synchronization, execute telemetry audits, and complete final sign-off.             |
+--------------------------------------------------------------------------------------------------------+
```

---

## 🛠️ 3. Execution Phase Deep Dive

### 📋 Phase 0: Pre-Upgrade Preparation (Week 0)

Major-version upgrades in Elasticsearch are restricted to specific upgrade paths. A direct upgrade to `9.x` is **only** supported from a healthy, fully-synchronized **v8.x** cluster (ideally the last minor release, such as `8.17.x`).

1.  **Intermediate Upgrades**: If current cluster version is below `8.17.x` (e.g., `8.12.x` or `8.15.x`), first execute an intermediate upgrade to the final `8.x` minor release.
2.  **Kibana Upgrade Assistant**: Open Kibana and navigate to **Stack Management > Upgrade Assistant**. Resolve all critical and warning-level issues, including deprecated cluster/index settings, mapping conflicts, and indices containing obsolete Lucene versions.
3.  **Snapshot Repository**: Establish a shared unprivileged backup store or locally capture full physical directory snapshots of `/opt/dsom-persistence/` to guarantee point-in-time recovery.
4.  **hardened Wolfi Image Readiness**: Compile or retrieve the updated `9.5.x` Wolfi image tags for Elasticsearch, Kibana, and Fleet Server. Ensure the underlying Base OS (Wolfi/apk) includes current security patches.

---

### 🚀 Week 1: Infrastructure and Core Stack Upgrade

#### 1. Update + Upgrade OS For Elasticsearch Cluster
*   **Host Upgrades**: Execute core OS updates on all physical or virtual hosts.
    *   *Debian/Ubuntu*: Run `sudo apt-get update && sudo apt-get dist-upgrade -y`
    *   *RPM-Based*: Run `sudo dnf clean all && sudo dnf upgrade -y`
*   **Podman Maintenance**: Upgrade Podman to version `5.x+` (or latest available) to inherit enhanced network stack drivers (such as Pasta) and secure Quadlet generators.
*   **Kernel Optimizations**: Re-verify and enforce WSL2/Linux host system controls as automated by our Ansible tasks:
    *   `vm.max_map_count` is set to at least `262144` (required for Elasticsearch memory-mapped allocations).
    *   `fs.inotify.max_user_watches` is raised to `524288`.
    *   Process file limits (`nofile`) are configured to `65535`.
*   **User Linger Status**: Ensure unprivileged deployment lingering is preserved: `sudo loginctl enable-linger <deployment_user>`.

#### 2. Upgrade Elasticsearch Cluster
*   **Multi-Node WSL / Hardware rolling upgrade**:
    1.  Disable shard allocation:
        ```json
        PUT _cluster/settings
        {
          "persistent": {
            "cluster.routing.allocation.enable": "primaries"
          }
        }
        ```
    2.  Stop the unprivileged node container or systemd Quadlet service:
        ```bash
        systemctl --user stop dsom-persistence-es-node-01.service
        ```
    3.  Update the image tag configuration in `ansible/group_vars/all.yml` or container manifests (`elk-wolfi/podman-compose-elasticsearch.yml`).
    4.  Restart the container node and monitor start progress via unprivileged systemd journal:
        ```bash
        journalctl --user -u dsom-persistence-es-node-01.service -f
        ```
    5.  Re-enable shard allocation once the node joins the cluster:
        ```json
        PUT _cluster/settings
        {
          "persistent": {
            "cluster.routing.allocation.enable": null
          }
        }
        ```
    6.  Repeat for remaining nodes (`es-node-02`, `es-node-03`) until cluster status returns to `green`.
*   **TLS Strict Mode**: Verify that `xpack.security.transport.ssl` and `xpack.security.http.ssl` settings are fully preserved in configuration matrices.

#### 3. Upgrade Kibana
*   **Container Switchover**: Stop the active Kibana service, update its container compose or Quadlet definition to reference the matching `9.5.x` Wolfi Kibana image, and launch:
    ```bash
    systemctl --user stop kib01.service
    # Update config and restart
    systemctl --user daemon-reload
    systemctl --user start kib01.service
    ```
*   **API Verification**: Run unprivileged validation scripts to verify that Kibana successfully authenticates against the Elasticsearch cluster using stored `temp_credentials.txt` or vault secrets.

#### 4. Upgrade Elastic Fleet Integration + Elastic Agent Related
*   **Upgrade Ordering Constraint**: **Fleet Server must be upgraded before any of its connected downstream Elastic Agents.** If an Elastic Agent is newer than the managing Fleet Server, connection failure or registry conflicts will occur.
*   **Orchestration Upgrades**:
    1.  In Kibana, upgrade the Fleet integration package in the global registry.
    2.  Stop the unprivileged Fleet Server container.
    3.  Upgrade the image reference to `9.5.x` and restart the container, ensuring secure `0600` permissions are preserved on generated environment files.

#### 5. Update OS Elastic Agent Fleet
*   Execute standard OS updates across all peripheral host machines running Elastic Agents (such as Gitea database hosts, Semaphore execution hosts, and remote web/database servers).
*   Validate unprivileged container system interfaces (e.g. Podman socket endpoints) which the Elastic Agent will monitor.

#### 6. Upgrade All Integrations Install - Not ML
*   Navigate to **Kibana > Fleet > Integrations**.
*   Select and upgrade out-of-the-box non-ML integrations (e.g., *System*, *Podman*, *PostgreSQL*, *Gitea*, *Linux*, *Docker*).
*   Test and verify that index template mapping updates are smoothly resolved and that incoming documents from Week 1 hosts are successfully indexed.

---

### 🧠 Week 2: Advanced Integrations, Airgap Security, and Final Sync

#### 7. Upgrade ML Integration, Make No Missing Pipeline
*   **Machine Learning (ML) Safeguards**:
    1.  Temporarily pause all active ML anomaly detection jobs and datafeeds before executing the upgrade to prevent data analysis gaps or mapping conflicts.
    2.  Execute the ML integration upgrade within Kibana Fleet.
    3.  Verify ingest pipelines (`_ingest/pipeline`) to ensure no custom pipeline processors (such as script processors or geoip lookups) are missing or deprecated in 9.x.
    4.  Resume ML datafeeds and verify that model states continue to process data seamlessly.

#### 8. Phase Out to Airgap If Needed
For environments that require sovereign isolation or disconnected (airgapped) operations:
*   **Local Image Registry**: Push the compiled `9.5.x` Wolfi Elastic containers to our local, rootless Gitea-managed container registry or local Docker distribution.
*   **Offline Fleet Package Registry (EPR)**: Configure Kibana and Fleet Server to pull integrations from a locally mirrored, self-signed HTTPS integration server instead of the public Elastic Package Registry (`epr.elastic.co`).
*   **Certificate Trust Store Integration**: Fully register local self-signed authority certificates into the host OS root trust and volume-mount them directly into the Fleet and Agent container namespaces (mirroring our secure Gitea/Semaphore trust setups).

#### 9. End of Syncup Elastic Agent
*   **Final Agent Rollouts**: Upgrade all managed Elastic Agents to `9.5.x` via the Fleet console or automated unprivileged shell execution.
*   **Enrollment Security**: Rotate old Fleet Enrollment Tokens, enforce TLS certificate verification on all agents, and restrict agent enrollment to strict client authentication.
*   **Telemetry Auditing**: Trigger our system-level Developer Telemetry collection (`execution_mode=dev`) to capture and write performance/log profiles directly to `/tmp/jules_telemetry.json` and verify CPU/Memory bounds.

---

## 📊 4. Upgrade Risk & Mitigation Matrix

| Potential Risk | Impact | Architectural Mitigation Strategy |
| :--- | :--- | :--- |
| **Index Mapping Conflicts** | High | Run Kibana Upgrade Assistant in Week 0. Ensure no indices remain on legacy `5.x`/`6.x` mapping models. |
| **SubUID/SubGID Ownership Reset** | Medium | Maintain `UserNS=keep-id` in all Quadlets and compose stacks to prevent host file access lockout. |
| **Fleet / Agent Version Mismatch** | High | Enforce strict upgrade sequence: Elasticsearch ➔ Kibana ➔ Fleet Server ➔ Elastic Agents. |
| **Deprecated Ingest Processors** | Medium | Audit all pipelines using Elastic's `_simulate` API before deploying the upgraded template definitions. |
| **Airgap Image Resolution Failures** | Medium | Ensure local registry hosts are fully registered in unprivileged Podman registry search registries (`/etc/containers/registries.conf`). |

---
*DSOM Systems Engineering | Elastic Stack 9.x Upgrade Roadmap v1.0*
{% endraw %}