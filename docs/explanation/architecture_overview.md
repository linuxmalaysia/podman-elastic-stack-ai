---
title: "Architecture Overview"
description: "Conceptual explanation of our structural topology, unprivileged workflows, and data boundary rules."
nav_order: 40
---

# Architecture Overview

This explanation guide outlines the core design goals, system boundaries, and structural elements of the deployment architecture.

---

## 🏛️ Component Boundaries

The project establishes three segregated operational layers:

```mermaid
flowchart TD
    User["Human Operator / CLI"] --> Controller["Ansible Controller"]
    Controller --> Podman["Podman Engine (Rootless/User Mode)"]
    subgraph Isolated Stack Net
        Podman --> ES["Hardened Wolfi Elasticsearch"]
        Podman --> Kib["Hardened Wolfi Kibana"]
        Podman --> Git["Sovereign Gitea"]
        Podman --> Sem["SemaphoreUI Quadlet Stack"]
    end
```

---

## 🔒 Unprivileged & Rootless Execution

Standard setups often run container runtimes with root privileges, creating potential privilege-escalation risks.

Our project enforces a **Strict Zero-Privilege Rule**:
1. All container tasks are managed under standard user permissions via rootless Podman execution contexts.
2. Port binding ranges are shifted above privileged values (e.g. mapping internal ports securely to host ranges such as `3000` or `5601`).
3. Services utilize a shared unprivileged user bridge that provides internal container connectivity and isolation from unrelated external host networks, rather than enforcing logical network isolation between the attached services themselves.
4. Separate from this bridge layer, host-port exposure is bounded: selected services are made accessible externally via explicitly configured interface bindings. Specifically, the setup helper scripts `setup_elasticsearch.sh` and `setup_kibana.sh` accept an optional `BIND_ADDRESS` parameter (defaulting to `127.0.0.1`) which enforces that public-facing container ports (e.g., `9200` and `5601`) bind strictly to the specified host interface.
