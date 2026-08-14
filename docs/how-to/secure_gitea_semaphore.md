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

Sovereign credentials are automatically created and isolated from Git tracking inside local `.txt` paths. Gitea credentials default to `gitea_credentials.txt` in the deployment directory. Semaphore credentials are saved to the path defined by `semaphore_credentials_file` (which defaults to `~/.config/containers/semaphoreui/secrets/semaphore_credentials.txt` but can be overridden with the `semaphore_credentials_override` variable):

*   **Gitea Secrets**: `gitea_credentials.txt`
*   **Semaphore Secrets**: Configured via `semaphore_credentials_file`


### Step 2: Enforce Strict File Permissions

Ensure secrets are not readable by other unprivileged system accounts. The chmod example should target the resolved configured path rather than assuming a current-directory filename:

```bash
# Secure the dynamically generated credentials files
chmod 0600 gitea_credentials.txt
chmod 0600 "${HOME}/.config/containers/semaphoreui/secrets/semaphore_credentials.txt"
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

The Semaphore deployment automatically mounts the host CA bundle directly inside the execution containers as a read-only volume:

```yaml
volumes:
  - /etc/ssl/certs:/etc/ssl/certs:ro
```

This read-only CA bundle enables Semaphore execution containers to verify server certificates for outbound HTTPS connections, establishing secure one-way server authentication. Client certificates are managed separately and are required only if mutual TLS (mTLS) is explicitly enforced for bidirectional verification.
