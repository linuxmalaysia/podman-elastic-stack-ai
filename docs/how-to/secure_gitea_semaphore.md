---
title: "Gitea & Semaphore Secure Operations"
description: "How to operate secure, unprivileged Gitea servers and trusted Semaphore pipelines."
nav_order: 22
---

# Gitea & Semaphore Secure Operations

This guide provides practical instructions for operating secure, unprivileged code servers and trusted CI pipelines in isolated rootless scopes.

---

## 🔒 Task 1: Generate High-Entropy Git Secrets Dynamically

If not manually set, Gitea playbooks dynamically generate strong passwords.

### Step 1: Identify Password Files
Sovereign credentials are automatically created and isolated from Git tracking inside local `.txt` paths:
* **Gitea Secrets**: `gitea_credentials.txt`
* **Semaphore Secrets**: `semaphore_credentials.txt`

### Step 2: Enforce Strict File Permissions
Ensure secrets are not readable by other unprivileged system accounts:
```bash
chmod 0600 gitea_credentials.txt semaphore_credentials.txt
```

---

## 🤝 Task 2: Configure TLS Trust for GitOps Execution

To enable Semaphore's `go-git` engine to securely clone repositories from local self-signed HTTPS Gitea instances, the self-signed certificate must be registered in the host CA store.

### Step 1: Register Certificate
```bash
sudo cp gitea.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### Step 2: Volume Mount Host Bundle
The Semaphore deployment automatically mounts the host CA bundle directly inside the execution containers:
```yaml
volumes:
  - /etc/ssl/certs:/etc/ssl/certs:ro
```
This ensures secure, bidirectional trusted pipeline integrations.
