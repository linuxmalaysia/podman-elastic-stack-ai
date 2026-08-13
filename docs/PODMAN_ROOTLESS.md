---
okf_version: 0.1
type: documentation
title: "PODMAN_ROOTLESS.md"
description: "Rootless Podman 5+ and systemd Quadlet orchestration guide."
topics: [podman, rootless, quadlet, security, documentation]
resource: file:///docs/PODMAN_ROOTLESS.md
timestamp: 2026-07-12T10:00:00Z
---
{% raw %}

# 🐳 Rootless Podman 5+ & Quadlet Orchestration Guide

This guide details the unprivileged, rootless container architecture utilized in our project, highlighting the secure deployment of Elasticsearch, Kibana, Fleet Server, Gitea, and Semaphore using systemd Quadlets and user-level container services.

---

## 1. Why Rootless Podman 5+ & Quadlets?

Legacy container runtimes run with administrative (root) privileges or rely on background daemons that require superuser access. This poses critical security vulnerabilities; if a container is compromised, the attacker can leverage rootful container system paths or daemon sockets to gain full administrative control of the host machine.

Our project implements unprivileged **Rootless Podman 5+** combined with **systemd Quadlets**. Systemd Quadlets convert declarative `.container`, `.volume`, `.pod`, and `.network` configuration files directly into unprivileged user-level systemd unit files on startup. This provides:
- **Zero-Daemon Overhead**: Podman behaves like a standard CLI utility, starting and stopping containers as child processes directly under the unprivileged systemd user session.
- **Sovereign Isolation**: Rootless mode reduces execution privileges and limits the impact of potential container compromises. However, rootless containerization does not absolutely guarantee that breakouts are completely blocked. Standard risks remain from kernel-level vulnerabilities, user-namespace flaws, container-runtime (crun/runc) exploits, or overly permissive host-path mounts. To maintain a strong security posture, defense-in-depth controls—such as read-only root filesystems, minimal container images (Wolfi), network namespace isolation, and strict host directory file permissions—must be layered alongside rootless mode.

---

## 2. Mandatory Environment Variables

To interact with unprivileged systemd managers, Ansible playbooks and runtime bash wrappers must operate within the correct user socket contexts.

- **`XDG_RUNTIME_DIR`**:
  Specifies the path where user-specific runtime files (such as unprivileged sockets, systemd control points, and lockfiles) must be stored. For rootless users, this defaults to `/run/user/<UID>` (e.g., `/run/user/1000`).
- **`DBUS_SESSION_BUS_ADDRESS`**:
  Points the unprivileged D-Bus client to the user-level message bus socket, typically located at `unix:path=/run/user/<UID>/bus`.

Without explicitly passing these variables to unprivileged execution environments, `systemctl --user` and user-level systemd daemon actions will fail with connection refused or socket authentication errors.

---

## 3. The keep-id Namespace Mapping Solution

By default, rootless Podman maps container internal UID `0` (root) to the unprivileged host user's UID (e.g., `1000`), and maps other internal non-root container UIDs (such as UID `1000` or `2001` inside the container) to high-range unallocated subuids (e.g., `102000`).
Without explicit namespace configuration, files created inside a container by an internal non-root user are assigned arbitrary subuid/subgid ownership on the host OS, which complicates local backups, data persistence, and permission management.

### Storage Sovereignty via UserNS=keep-id

To align unprivileged host permissions natively without requiring elevated host privileges or dynamic directory-permission modifications, we enforce namespace mapping using `keep-id` at the container and pod levels.

For example, specifying the following in our container unit files:

```ini
UserNS=keep-id:uid=1000,gid=1000
```

instructs Podman to map UID `1000` inside the container directly to UID `1000` on the host OS. This guarantees that files created inside the container's persistent storage mount preserve correct ownership under the host user's standard account.

---

## 4. Enabling Systemd Lingering for Rootless Users

By default, unprivileged user-level systemd managers are initiated upon user login and completely terminated when the user logs out. For background services (such as Elasticsearch clusters, Kibana portals, or Gitea/Semaphore instances) to persist and run continuously across system reboots and logouts, **systemd lingering** must be explicitly enabled for the service account.

### Playbook Strategy for Unified Deployment User

To ensure correct unprivileged execution context—even when connecting via an administrative account or a root/sudo-escalated connection—our playbooks define a single, unified `deployment_user` variable (e.g., `dsom-admin` or the resolved unprivileged account). This variable is consistently reused to configure lingering, resolve user-level file/systemd paths, and control Quadlets, replacing any inconsistent or fragile direct references to `ansible_user_id` or `ansible_env.HOME`.

The playbook automates linger configuration via:

```yaml
- name: Enable systemd lingering for deployment user
  ansible.builtin.command:
    cmd: "loginctl enable-linger {{ deployment_user }}"
    creates: "/var/lib/systemd/linger/{{ deployment_user }}"
  become: yes
```

This guarantees that unprivileged container runtimes start automatically during host boot sequence, and survive logout.

---

## 5. Declarative Quadlet and Compose Configurations

Our stack supports both Docker-compose-like unprivileged playbooks (using `podman-compose`) and systemd Quadlet files for services like Gitea and Semaphore.

### Example: Gitea Stack Quadlet Kube (`gitea-stack.kube`)

```ini
[Unit]
Description=Sovereign Gitea Stack (Quadlet Kube)

[Kube]
Yaml=gitea-stack.yaml

[Install]
WantedBy=default.target
```

### Quadlet Service Lifecycle Management

When deploying or updating declarative Quadlet configurations under unprivileged user-sessions, standard systemd commands must be executed sequentially to register and run the service:

1. **Daemon Reload**: Reload the unprivileged user-level systemd daemon to scan and compile the new or modified `.kube` or `.container` files into generated unit files:

   ```bash
   systemctl --user daemon-reload
   ```

2. **Start the Service**: Direct container startup is handled by starting the corresponding unprivileged systemd unit:

   ```bash
   systemctl --user start gitea-stack.service
   ```

3. **Automatic Startup on Boot**: The `[Install]` block (`WantedBy=default.target`) within the Quadlet file natively handles automatic unprivileged service startup when the system boots (provided systemd lingering is enabled). Under Podman Quadlet specifications, unprivileged users must **not** run `systemctl --user enable` manually on generated Quadlet units, as doing so will create conflicting systemd links.

Once started, verify the active stack status and logs using standard unprivileged systemd tools:

```bash
systemctl --user status gitea-stack.service
```

---
*DSOM Engineering | Rootless Podman 5+ & Quadlet Guide v1.0*
{% endraw %}
