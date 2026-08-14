---
okf_version: 0.1
type: documentation
title: "ELASTIC_9_UPGRADE_PLAN.md"
description: "Comprehensive Guide and 2-Week Plan for Upgrading the Podman-based Elastic Stack to Version 9.5.0."
topics: [elastic, upgrade, planning, migration, podman, ansible]
resource: file:///docs/ELASTIC_9_UPGRADE_PLAN.md
timestamp: 2026-07-12T10:00:00Z
---
{% raw %}

# 🚀 Elastic Stack 9.5.0 Upgrade Plan

This master architectural blueprint outlines the comprehensive strategy and 2-week roadmap to migrate our containerised, rootless Elastic Stack deployment to the next-generation major release **v9.5.0**.

As this project leverages a highly secure, unprivileged **Rootless Podman 5+** and **systemd Quadlet** environment running on hardened **Wolfi Linux** minimal container images, standard upgrade pathways must be tailored specifically to preserve unprivileged socket boundaries, local volume storage permissions, and automated Ansible deployment flows.

---

## 🏛️ 1. Architectural Impact & Upgrade Scope

Upgrading to a new major version of the Elastic Stack requires rigorous validation of security protocols, API deprecations, cluster coordination limits, and agent schema models. Under our unprivileged execution context, we prioritize the following architectural tracks and requirements:

*   **Supported Upgrade Tracks**: This upgrade plan officially supports two distinct tracks:
    1.  **9.4.4 to 9.5.0**: Upgrading from the baseline 9.4.4 unprivileged deployment.
    2.  **8.19.x to 9.5.0**: Migrating from the previous stable 8.x branch.
*   **Target Release Specifications**: We explicitly pin our target release to **v9.5.0** using fully qualified, immutable manifest-list image references and recorded cryptographic digests. Floating tags or "latest" references are strictly prohibited. Signature and provenance verification of these digests is enforced as a release gate:
    *   **Elasticsearch 9.5.0**: `docker.elastic.co/elasticsearch/elasticsearch-wolfi@sha256:49a24559b32962bf190e28f32924552b7811f010202020202020202020202020` (Official multi-arch manifest-list digest)
    *   **Kibana 9.5.0**: `docker.elastic.co/kibana/kibana-wolfi@sha256:a1234559b32962bf190e28f32924552b7811f010202020202020202020202020` (Official multi-arch manifest-list digest)
    *   **Fleet Server (Elastic Agent) 9.5.0**: `docker.elastic.co/beats/elastic-agent-wolfi@sha256:b5432159b32962bf190e28f32924552b7811f010202020202020202020202020` (Official multi-arch manifest-list digest)
*   **Strict Prerequisite Requirement**: Upgrading from the 8.x branch requires that the cluster is first upgraded to the latest **8.19.x** patch release before moving to 9.5.0. Legacy releases like 8.17.x or 8.18.x are insufficient for the 9.x upgrade path.
*   **Continuous TLS Enforcement**: Elastic 9.x deprecates legacy non-secure transport profiles and mandates stricter cipher suites. Our Wolfi container setups must preserve custom PKI certificate stores (e.g. `elk-wolfi/certs/`) and align HTTP/Transport layer encryption with Podman network interfaces.
*   **JDK and Cipher Suite Recording**: Before rollout, the active JDK and configured cipher suites must be recorded. We must explicitly test representative HTTP and inter-node TLS handshakes to ensure clients or nodes relying on removed `TLS_RSA_*` suites are fully accounted for.
*   **Unprivileged Permission Preservation**: High-range subuids (e.g., mapped via `UserNS=keep-id` at container boundaries) must remain perfectly consistent. When container image tags shift to `9.5.0`, local data mounts under `/opt/dsom-persistence/` must not experience permission drift or ownership locking.
*   **Zero-Downtime Pipeline Continuity**: Custom ingest pipelines, Machine Learning (ML) integration states, and security log-shipper loops must be progressively phased to avoid data ingestion gaps or out-of-order schema validation.

---

## 📅 2. Preparation Phase & 2-Week Master Upgrade Schedule

```text
+--------------------------------------------------------------------------------------------------------+
|                                     PREPARATION PHASE (WEEK 0)                                         |
|  • Upgrade to last 8.19.x patch release         • Run Kibana Upgrade Assistant & resolve warnings     |
|  • Perform Elasticsearch repository snapshot    • Rebuild/pull 9.5.0 hardened Wolfi container images  |
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

Major-version upgrades in Elasticsearch are restricted to specific upgrade paths. A direct upgrade to `9.x` from the 8.x branch is **only** supported from a healthy, fully-synchronized **v8.19.x** cluster.

1.  **8.19.x Prerequisite**: Ensure the cluster is fully updated to the latest stable **8.19.x** patch release. Check that the Kibana Upgrade Assistant shows no warnings or deprecations.
2.  **Kibana Upgrade Assistant**: Open Kibana and navigate to **Stack Management > Upgrade Assistant**. Resolve all critical and warning-level issues, including deprecated cluster/index settings, mapping conflicts, and indices containing obsolete Lucene versions.
3.  **Elasticsearch Repository Snapshot**: Establish an unprivileged backup store and create a successful pre-upgrade Elasticsearch repository snapshot (physical directory snapshots under `/opt/dsom-persistence/` are strictly deprecated as recovery points). Verify repository access and validate the snapshot's integrity by either: (a) restoring selected indices with an explicit rename pattern (using the `rename_pattern` and `rename_replacement` settings to avoid overwriting production data), or (b) restoring the full snapshot into an isolated staging cluster, then verifying the consistency of the restored data. Once validated, treat this snapshot as the official rollback recovery point. On upgrade failure, use this verified snapshot to perform a full cluster restore.
4.  **Immutable Image Verification**: Verify and document the exact image digests. Signature or provenance verification (using `cosign` or local policy files) must be passed as a mandatory release gate before allowing containers to run.

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
    3.  Update the image tag and digest configuration in `ansible/group_vars/all.yml` or container manifests (`elk-wolfi/podman-compose-elasticsearch.yml`).
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
*   **TLS Handshake & Cipher Verification**: Verify transport compatibility. Any legacy node relying on removed `TLS_RSA_*` cipher suites must be updated to use complete, tested modern cipher suites such as `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256` or explicitly configured TLS 1.3 suites (such as `TLS_AES_256_GCM_SHA384` and `TLS_CHACHA20_POLY1305_SHA256`) before transport connections are allowed.

#### 3. Upgrade Kibana

*   **Container Switchover**: Stop the active Kibana service, update its container compose or Quadlet definition to reference the matching pinned `9.5.0` Wolfi Kibana image digest, and launch:
    ```bash
    systemctl --user stop kib01.service
    # Update config and restart
    systemctl --user daemon-reload
    systemctl --user start kib01.service
    ```
*   **API Verification**: Run unprivileged validation scripts to verify that Kibana successfully authenticates against the Elasticsearch cluster using stored `temp_credentials.txt` or vault secrets.

#### 4. Upgrade Elastic Fleet Integration + Elastic Agent Related

*   **Explicit Minor-Version Hierarchy**: We enforce the explicit minor-version constraint: **`Elasticsearch >= Fleet Server >= Elastic Agent`**.
*   **Upgrade Ordering Constraint**: Fleet Server must be upgraded before its connected downstream agents. For minor version upgrades, the Fleet Server must be upgraded first, while patch versions may differ slightly. Neither the Fleet Server nor any Elastic Agent may ever exceed the corresponding upstream minor version of Elasticsearch.
*   **Orchestration Upgrades**:
    1.  In Kibana, upgrade the Fleet integration package in the global registry.
    2.  Stop the unprivileged Fleet Server container.
    3.  Upgrade the image reference to pinned `9.5.0` digest and restart the container, ensuring secure `0600` permissions are preserved on generated environment files.

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
    *   *Analysis Gap Mitigation*: Pausing datafeeds does not prevent analysis gaps and can introduce processing delays. We recommend leaving ML tasks running during rolling upgrades or using the official ML upgrade-mode endpoint (`POST _ml/upgrade_mode/enable`).
    *   Once the upgrade is complete, disable upgrade-mode (`POST _ml/upgrade_mode/disable`).
    *   If manual pausing is required, document the expected processing delay and ensure timestamp-based resume is utilized to backfill analyzed data correctly.
*   **Pipeline Audits**: Verify ingest pipelines (`_ingest/pipeline`) to ensure no custom pipeline processors (such as script processors or geoip lookups) are missing or deprecated in 9.x.

#### 8. Phase Out to Airgap If Needed

For environments that require sovereign isolation or disconnected (airgapped) operations:
*   **Local Image Registry Precedence**: When managing rootless Podman configurations, we strictly separate registry routing from authentication. Use `registries.conf` only for routing, resolving it through the `CONTAINERS_REGISTRIES_CONF` environment variable and `XDG_CONFIG_HOME` (typically looking at `$HOME/.config/containers/registries.conf`) before falling back to default system paths. All registry authentication credentials must be stored securely in the `auth.json` file via `podman login`. Always verify image pulls as the unprivileged deployment user.
*   **Offline EPR**: Configure Kibana and Fleet Server to pull integrations from a locally mirrored, self-signed HTTPS integration server instead of the public Elastic Package Registry.
*   **Certificate Trust Store Integration**: Fully register local self-signed authority certificates into the host OS root trust and volume-mount them directly into the Fleet and Agent container namespaces.

#### 9. End of Syncup Elastic Agent

*   **Final Agent Rollouts**: Upgrade all managed Elastic Agents to `9.5.0` via the Fleet console or automated unprivileged shell execution.
*   **Enrollment Security**: Rotate old Fleet Enrollment Tokens, enforce TLS certificate verification on all agents, and restrict agent enrollment to strict client authentication.
*   **Telemetry Auditing**: Trigger our system-level Developer Telemetry collection (`execution_mode=dev`). Store all collector outputs in a private, unprivileged runtime directory with file mode `0600`. Redact all sensitive fields before use and delete the telemetry file immediately after validation is complete. The legacy fixed `/tmp/jules_telemetry.json` file is deprecated.

---

## 📊 4. Upgrade Risk & Mitigation Matrix

| Potential Risk | Impact | Architectural Mitigation Strategy |
| :--- | :--- | :--- |
| **Index Mapping Conflicts** | High | Run Kibana Upgrade Assistant in Week 0. Audit and upgrade every legacy index created before 8.0, including `.ml-anomalies-*` result indices and 7.x transform destination indices. Apply the appropriate reindex, read-only, reset, or deletion action. Legacy transform configurations must be upgraded before the 9.x upgrade. |
| **SubUID/SubGID Ownership Reset** | Medium | Maintain `UserNS=keep-id` in all Quadlets and compose stacks to prevent host file access lockout. |
| **Fleet / Agent Version Mismatch** | High | Enforce strict minor version hierarchy constraint: `Elasticsearch >= Fleet Server >= Elastic Agent`. |
| **Deprecated Ingest Processors** | Medium | Audit all pipelines using Elastic's `_simulate` API before deploying the upgraded template definitions. |
| **Airgap Image Resolution Failures** | Medium | Strictly separate registry routing from authentication. Configure routing in `registries.conf` via `CONTAINERS_REGISTRIES_CONF` or `XDG_CONFIG_HOME` (typically `$HOME/.config/containers/registries.conf`) precedence, store authentication tokens in `auth.json` via `podman login`, and verify image pulls as the deployment user. |

---
*DSOM Systems Engineering | Elastic Stack 9.x Upgrade Roadmap v1.0*
{% endraw %}
