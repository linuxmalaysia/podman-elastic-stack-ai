---
title: "Documentation Home"
description: "Welcome to the Podman-based Elastic Stack and Gitea/Semaphore deployment documentation system."
nav_order: 1
---

# Sovereign Infrastructure Documentation

Welcome to our production-ready, structured documentation system. This documentation is organized into four distinct categories according to the **Diátaxis Framework**:

- **[Tutorials](tutorials/installation.md)**: Learning-oriented, step-by-step lessons to help you get started from scratch.
- **[How-To Guides](how-to/system_tuning.md)**: Task-oriented, practical directions for specific, real-world problems.
- **[Reference](reference/cli_scripts.md)**: Information-oriented, comprehensive technical descriptions, parameters, and specifications.
- **[Explanation](explanation/architecture_overview.md)**: Understanding-oriented, architectural maps, concept details, and high-level decisions.

---

## 🗺️ Navigation Map


### Tutorials

1. **[Step-by-Step Installation](tutorials/installation.md)**: Build an unprivileged, rootless single-node Elastic Stack on WSL2 or bare-metal Linux.
2. **[Ansible Quickstart](tutorials/ansible_quickstart.md)**: Get up and running with our Ansible playbooks in less than five minutes.


### How-To Guides

1. **[System Tuning & Optimization](how-to/system_tuning.md)**: Apply kernel rules (`vm.max_map_count`, memory limits) on WSL2 or Linux hosts.
2. **[Distributed WSL2 Cluster](how-to/wsl2_cluster.md)**: Scale up a simulated multi-node high-availability Elastic Cluster.
3. **[Gitea & Semaphore Secure Operations](how-to/secure_gitea_semaphore.md)**: Set up rootless git servers and secure, trusted CI pipelines.


### Upgrade Plans

1. **[Elastic 9.5.0 Upgrade Plan](ELASTIC_9_UPGRADE_PLAN.md)**: Master architectural blueprint and 2-week upgrade roadmap.


### Reference

1. **[CLI Scripts Reference](reference/cli_scripts.md)**: Detailed option and interface breakdown for setup and feedback scripts.
2. **[Ansible Playbooks Spec](reference/playbooks_spec.md)**: Complete map of roles, tasks, variables, and telemetry logs.
3. **[Podman Compose Configurations](reference/compose_configs.md)**: Core environment attributes, resource bounds, and network topologies.
4. **[MkDocs Rewriter Hook API](reference/mkdocs_hook_api.md)**: Functional parameters, regex patterns, and normalization mechanics.


### Explanation

1. **[Architecture Overview](explanation/architecture_overview.md)**: Core structural topology, unprivileged workflows, and data boundary rules.
2. **[Hardened Wolfi Images & Security Decisions](explanation/security_decisions.md)**: Snyk audit, Zero-CVE Wolfi bases, TLS trust setups, and telemetry logging bounds.
3. **[Diátaxis Framework Integration](explanation/diataxis.md)**: Comprehensive explanation of the Diátaxis architecture in this workspace.
