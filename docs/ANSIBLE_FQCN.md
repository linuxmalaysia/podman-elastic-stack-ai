---
okf_version: 0.1
type: documentation
title: "ANSIBLE_FQCN.md"
description: "Ansible best practices, FQCN, and unprivileged service orchestration guide."
topics: [ansible, fqcn, security, best-practices, playbooks]
resource: file:///docs/ANSIBLE_FQCN.md
timestamp: 2026-07-12T10:00:00Z
---
{% raw %}
# 🤖 Ansible Best Practices & Rootless Service Orchestration Guide

This guide compiles modern Ansible standards adopted in our project to manage unprivileged container setups, enforce Fully Qualified Collection Names (FQCN), and implement a symmetric privilege separation strategy.

---

## 1. Fully Qualified Collection Names (FQCN)

Modern Ansible mandates the use of **Fully Qualified Collection Names (FQCN)** (e.g., `ansible.builtin.copy` instead of `copy`, or `ansible.builtin.template` instead of `template`). Enforcing FQCN:
- **Prevents Naming Collisions**: Avoids module lookup confusion when custom community collections are installed in the same environment.
- **Guarantees Predictability**: Ensures playbooks are forward-compatible across Ansible Core upgrades.
- **Enterprise Grade**: Meets Red Hat enterprise standards and Ansible Galaxy deployment rules.

Our project strictly enforces FQCN syntax in all tasks across Elasticsearch, Kibana, Fleet, Gitea, and Semaphore playbooks.

---

## 2. 🛡️ Symmetric Privilege Strategy

To achieve a hardened security posture, Ansible playbooks must decouple administrative host operations from the deployment of unprivileged application containers.

### A. Rootful OS Hardening (Superuser Privilege)
- **Role**: Performed with `become: yes` (sudo as root).
- **Actions**: Installs packages (`podman`, `podman-compose`), manages kernel tuning (adjusting `vm.max_map_count`, `fs.inotify.max_user_watches`), creates system user/groups, and configures OS security baselines in `/etc/wsl.conf` or `/etc/security/limits.conf`.

### B. Rootless Deployments (Unprivileged Privilege)
- **Role**: Performed with the context of the unprivileged deployment user (e.g., `become: yes` combined with `become_user: dsom-admin` or similar, or executed directly from user workspace connection).
- **Actions**: Creates unprivileged data volumes, writes user-level configuration templates to `~/.config/containers/systemd/` or standard paths, reloads unprivileged user-level systemd daemons, and manages active container states.

---

## 3. Quadlet File Placement & Systemd User-Sockets

Declarative Quadlet unit configurations are evaluated directly from designated paths within the unprivileged user's directory:
- **Designated Destination**: `~/.config/containers/systemd/`

This directory is monitored natively by the unprivileged user-level systemd manager. Placing files here allows unprivileged service generation to be declared and activated seamlessly without administrative intervention.

### FQCN Ansible Blueprint

Below is an example of an unprivileged task using proper FQCN and passing user-level systemd environment sockets:

```yaml
- name: Create Quadlet configuration directory
  ansible.builtin.file:
    path: "/home/{{ resolved_username }}/.config/containers/systemd"
    state: directory
    owner: "{{ resolved_username }}"
    group: "{{ resolved_username }}"
    mode: '0755'

- name: Deploy Quadlet templates
  ansible.builtin.template:
    src: "templates/gitea.kube.j2"
    dest: "/home/{{ resolved_username }}/.config/containers/systemd/gitea-stack.kube"
    owner: "{{ resolved_username }}"
    group: "{{ resolved_username }}"
    mode: '0644'
  register: quadlets_deployed

- name: Reload user-level systemd daemon and restart service
  ansible.builtin.systemd_service:
    daemon_reload: yes
    scope: user
    name: gitea-stack.service
    state: restarted
    enabled: yes
  environment:
    XDG_RUNTIME_DIR: "/run/user/{{ resolved_uid | default(1000) }}"
    DBUS_SESSION_BUS_ADDRESS: "unix:path=/run/user/{{ resolved_uid | default(1000) }}/bus"
  when: quadlets_deployed.changed
```

---

## 4. Troubleshooting Unprivileged Executions

- **Error: `Failed to connect to bus`**: Ensure systemd lingering is explicitly enabled for the target user session and both `XDG_RUNTIME_DIR` and `DBUS_SESSION_BUS_ADDRESS` are passed inside the task's `environment:` block.
- **Permission Denied inside Storage Path**: Confirm that unprivileged storage mounts have recursively assigned UID/GID permissions for the user (e.g., `1000:1000` or `1000` namespace mappings) before executing container startup scripts.

---
*DSOM Engineering | Ansible FQCN & Best Practices Guide v1.0*
{% endraw %}
