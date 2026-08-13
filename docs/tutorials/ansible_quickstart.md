---
title: "Ansible Quickstart Tutorial"
description: "Beginner-friendly tutorial to orchestrate your infrastructure with Ansible playbooks."
nav_order: 31
---

# Ansible Quickstart Tutorial

This tutorial introduces you to automating the deployment of Gitea, Semaphore, and the Elastic Stack using modular Ansible playbooks.

---

## 🎓 Learning Objectives
By the end of this tutorial, you will be able to:
1. Define simple variables in Ansible group inventories.
2. Run baseline pre-flight checks and host configurations.
3. Deploy an isolated, secure services playbook.

---

## 🛠️ Step 1: Install Ansible Dependencies

Ensure that Ansible is installed on your control node or WSL2 environment.

```bash
ansible --version
```

Install community module collections specified in our requirements:
```bash
ansible-galaxy collection install -r collections/requirements.yml
```

---

## 📋 Step 2: Set Host Configurations

We configure local single-node deployments using `inventory/hosts.yml`:

```yaml
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: /usr/bin/python3
```

Define shared variables (ports, directories) in `ansible/group_vars/all.yml`.

---

## 🚀 Step 3: Run the Main Playbook

To provision all servers, execute the master playbook:

```bash
ansible-playbook -i inventory/hosts.yml site.yml
```

This runs a sequence of secure tasks, ensuring standard configurations and isolated container operations.
