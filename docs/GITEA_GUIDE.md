---
okf_version: 0.2
type: documentation
title: "Sovereign Gitea Deployment & Security Operations Guide"
timestamp: "2026-08-30T00:00:00Z"
topics: ["gitea", "gitops", "podman", "ansible", "https", "security", "how-to"]
description: "Diátaxis How-To Guide for standalone installation of Sovereign Gitea in rootless Podman with HTTPS TLS configuration using CLI Pods/Quadlets and Ansible Playbook."
resource: "file:///docs/GITEA_GUIDE.md"
sources:
  - url: "https://github.com/linuxmalaysia/podman-elastic-stack-ai"
    description: "Podman Elastic Stack AI Repository"
generated: false
verified: true
status: "active"
stale_after: "2027-08-30T00:00:00Z"
---
{% raw %}

# Sovereign Gitea Deployment & Security Operations Guide

This guide details the standalone deployment, HTTPS/TLS configuration, automated setup, and secure operation of Gitea inside a rootless Podman stack. It is structured as a Diátaxis How-To Guide, optimized for both human engineers and AI Agents/bots.

<!-- markdownlint-disable-file MD041 -->

Sovereign self-hosting ensures code and infrastructure-as-code remain independent, secure, and resilient. This document provides step-by-step How-To instructions for two installation methods:
1. **How-To 1: Pure Command-Line & Podman Quadlet Deployment**
2. **How-To 2: Automated Ansible Playbook Deployment**

---

## 1. Overview & Architecture

Gitea is deployed natively on unprivileged rootless Podman infrastructure (using Podman Pods or systemd Quadlets). It serves as the local "Sovereign" Source of Truth for all GitOps repositories.

### Key Architecture Specs
- **Target Domain / Host IP:** `10.17.250.28` (or your host IP / FQDN)
- **Database Backend:** PostgreSQL 15 (Alpine)
- **Application Server:** Gitea 1.26.1
- **HTTP/HTTPS Port:** `3000` (Mapped to container port `3000` over HTTPS)
- **SSH Port:** `2222` (Mapped to container port `22` for Git over SSH)
- **Security & Protocol:** HTTPS enforced with TLS certificates signed by Sovereign CA.
- **Automated Bypass:** Gitea Web UI installer is bypassed programmatically via runtime environment variables (`GITEA__security__INSTALL_LOCK: "true"`).

---

## 2. Prerequisites

Before running any installation steps, verify the host system requirements:

### Clone the Repository

Clone the project repository to access setup playbooks, configurations, and reference templates:

```bash
# Clone the repository
git clone https://github.com/linuxmalaysia/podman-elastic-stack-ai.git

# Navigate into the project directory
cd podman-elastic-stack-ai
```

For more details on initial repository setup, see the [Git Repository guide in INSTALL.md](INSTALL.md#git-repository).

### Enable User Linger
Rootless container services run within unprivileged user space. Enabling linger ensures systemd user daemons and containers remain active across reboots and SSH session logouts:
```bash
sudo loginctl enable-linger $(whoami)
```

### Verify Podman & Dependencies
Confirm that Podman (v4+ or v5+) and Podman Compose are installed:
```bash
podman --version
podman-compose --version
```

---

## 3. How-To 1: Pure Command-Line & Quadlet Deployment (Standalone Manual)

Use this method to manually provision a standalone HTTPS-enabled Gitea stack using Podman CLI or native systemd Quadlet manifests.

### Step A: Generate TLS Certificates & Directory Setup

Gitea requires SSL/TLS certificates for HTTPS operation.

1. **Create Configuration and Certificate Directories**:
   ```bash
   mkdir -p ~/.config/gitea/certs
   chmod 0755 ~/.config/gitea/certs
   ```

2. **Generate Private Key and Self-Signed / Sovereign Certificate**:
   ```bash
   # Generate 2048-bit RSA Private Key with owner-only permissions (0600)
   openssl genrsa -out ~/.config/gitea/certs/gitea.key 2048
   chmod 0600 ~/.config/gitea/certs/gitea.key

   # Generate 5-year Self-Signed / Sovereign Certificate with Subject Alt Name (SAN) matching your target host IP/FQDN
   openssl req -new -x509 -key ~/.config/gitea/certs/gitea.key \
     -out ~/.config/gitea/certs/gitea.crt -days 1825 \
     -subj "/C=MY/ST=Kuala Lumpur/L=Kuala Lumpur/O=Sovereign/OU=IT/CN=10.17.250.28" \
     -addext "subjectAltName = DNS:10.17.250.28, IP:10.17.250.28, DNS:localhost, IP:127.0.0.1"
   chmod 0644 ~/.config/gitea/certs/gitea.crt
   ```

   *Security & Rootless Note: Private keys should be protected with `0600` permissions on the host. When mounting into unprivileged rootless Podman containers, Podman's user namespace mapping ensures the internal process UID matches host user ownership, allowing the container to read the `0600` key file securely without granting world-readability.*

3. **Install Sovereign CA in Host Trust Store**:
   - **On Debian/Ubuntu**:
     ```bash
     sudo cp ~/.config/gitea/certs/gitea.crt /usr/local/share/ca-certificates/sovereign-gitea-ca.crt
     sudo update-ca-certificates
     ```
   - **On RedHat/CentOS/AlmaLinux**:
     ```bash
     sudo cp ~/.config/gitea/certs/gitea.crt /etc/pki/ca-trust/source/anchors/sovereign-gitea-ca.crt
     sudo update-ca-trust
     ```

### Step B: Create Storage Volumes & Podman Pod

1. **Create Podman Pod with HTTP (3000) and SSH (2222) Port Mappings**:
   ```bash
   podman pod create \
       --name gitea-stack \
       --publish 3000:3000 \
       --publish 2222:22
   ```

2. **Create Storage Volumes**:
   ```bash
   podman volume create gitea_db_data
   podman volume create gitea_app_data
   ```

### Step C: Secure Secrets Management (`gitea.env`)

To prevent embedding plaintext credentials in CLI parameters or systemd unit files, store environment secrets in a strict `0600` file:

```bash
cat <<EOF > gitea.env
POSTGRES_USER=gitea
POSTGRES_PASSWORD=dSoM_G1t3a_H@rd3n3d_99X
POSTGRES_DB=gitea
GITEA__database__DB_TYPE=postgres
GITEA__database__HOST=127.0.0.1:5432
GITEA__database__NAME=gitea
GITEA__database__USER=gitea
GITEA__database__PASSWD=dSoM_G1t3a_H@rd3n3d_99X
GITEA__server__PROTOCOL=https
GITEA__server__DOMAIN=10.17.250.28
GITEA__server__ROOT_URL=https://10.17.250.28:3000/
GITEA__server__HTTP_PORT=3000
GITEA__server__SSH_PORT=2222
GITEA__server__CERT_FILE=/etc/gitea/certs/gitea.crt
GITEA__server__KEY_FILE=/etc/gitea/certs/gitea.key
GITEA__security__INSTALL_LOCK=true
EOF
chmod 0600 gitea.env
```

### Step D: Deploy PostgreSQL Database Container

Deploy PostgreSQL 15 within the rootless pod:

```bash
podman run --detach \
    --name gitea-db \
    --pod gitea-stack \
    --restart always \
    --env-file gitea.env \
    --volume gitea_db_data:/var/lib/postgresql/data:Z \
    docker.io/library/postgres:15-alpine \
    -c max_connections=100 \
    -c shared_buffers=256MB \
    -c work_mem=16MB \
    -c maintenance_work_mem=64MB \
    -c effective_cache_size=768MB
```

### Step E: Deploy Gitea HTTPS Application Container

Deploy Gitea 1.26.1 with volume mounts for certificates, application data, and timezone:

```bash
podman run --detach \
    --name gitea-app \
    --pod gitea-stack \
    --restart always \
    --env-file gitea.env \
    --volume gitea_app_data:/data:Z \
    --volume ~/.config/gitea/certs:/etc/gitea/certs:ro \
    --volume /etc/localtime:/etc/localtime:ro \
    docker.io/gitea/gitea:1.26.1
```

### Step F: Systemd Quadlet & Unit File Integration

To manage the standalone stack via user-level systemd:

1. **Using Podman Systemd Generation**:
   ```bash
   mkdir -p ~/.config/systemd/user/
   cd ~/.config/systemd/user/
   podman generate systemd --name gitea-stack --files --new
   systemctl --user daemon-reload
   systemctl --user enable --now pod-gitea-stack.service
   ```

2. **Alternatively: Using Podman 5 Native Quadlet Kube (`gitea-stack.kube` & `gitea-stack.yaml`)**:
   Create `~/.config/containers/systemd/gitea-stack.kube`:
   ```ini
   [Unit]
   Description=Gitea GitOps Service (Podman Kube Quadlet)
   After=network-online.target

   [Kube]
   Yaml=gitea-stack.yaml
   PublishPort=3000:3000
   PublishPort=2222:22

   [Install]
   WantedBy=default.target
   ```

   Create the supporting Kubernetes Pod workload manifest `~/.config/containers/systemd/gitea-stack.yaml` referenced by `Yaml=gitea-stack.yaml`:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     labels:
       app: gitea-stack
     name: gitea-stack
   spec:
     containers:
       - name: gitea-db
         image: docker.io/library/postgres:15-alpine
         args:
           - -c
           - max_connections=100
           - -c
           - shared_buffers=256MB
           - -c
           - work_mem=16MB
           - -c
           - maintenance_work_mem=64MB
           - -c
           - effective_cache_size=768MB
         env:
           - name: POSTGRES_USER
             value: gitea
           - name: POSTGRES_PASSWORD
             value: "dSoM_G1t3a_H@rd3n3d_99X"
           - name: POSTGRES_DB
             value: gitea
         volumeMounts:
           - mountPath: /var/lib/postgresql/data
             name: gitea-db-data

       - name: gitea-app
         image: docker.io/gitea/gitea:1.26.1
         ports:
           - containerPort: 3000
             hostPort: 3000
           - containerPort: 22
             hostPort: 2222
         env:
           - name: GITEA__database__DB_TYPE
             value: postgres
           - name: GITEA__database__HOST
             value: 127.0.0.1:5432
           - name: GITEA__database__NAME
             value: gitea
           - name: GITEA__database__USER
             value: gitea
           - name: GITEA__database__PASSWD
             value: "dSoM_G1t3a_H@rd3n3d_99X"
           - name: GITEA__server__PROTOCOL
             value: https
           - name: GITEA__server__DOMAIN
             value: "10.17.250.28"
           - name: GITEA__server__ROOT_URL
             value: "https://10.17.250.28:3000/"
           - name: GITEA__server__HTTP_PORT
             value: "3000"
           - name: GITEA__server__CERT_FILE
             value: /etc/gitea/certs/gitea.crt
           - name: GITEA__server__KEY_FILE
             value: /etc/gitea/certs/gitea.key
           - name: GITEA__security__INSTALL_LOCK
             value: "true"
         volumeMounts:
           - mountPath: /data
             name: gitea-app-data
           - mountPath: /etc/gitea/certs
             name: gitea-certs
             readOnly: true
           - mountPath: /etc/localtime
             name: etc-localtime
             readOnly: true

     volumes:
       - name: gitea-db-data
         persistentVolumeClaim:
           claimName: gitea_db_data
       - name: gitea-app-data
         persistentVolumeClaim:
           claimName: gitea_app_data
       - name: gitea-certs
         hostPath:
           path: /home/dsom-admin/.config/gitea/certs
           type: Directory
       - name: etc-localtime
         hostPath:
           path: /etc/localtime
           type: File
   ```

   Reload systemd and start:
   ```bash
   systemctl --user daemon-reload
   systemctl --user start gitea-stack.service
   ```

---

## 4. How-To 2: Automated Ansible Playbook Deployment (Recommended)

Our repository includes a fully idempotent Ansible playbook (`ansible/setup_gitea.yml`) to deploy Gitea rootless, manage TLS certificates, and handle runtime credentials automatically.

For complete playbook architecture details, refer to the [Playbooks Guide](PLAYBOOKS.md).

### Playbook Features & Security Workflow
1. **OS Package Provisioning**: Automatically detects Debian/Ubuntu (`apt`) or RPM distributions (`dnf`) and installs `podman` and `podman-compose`.
2. **User Linger Verification**: Invokes `loginctl enable-linger` for the deployment user account.
3. **Automated High-Entropy Password Generation**: Checks for existing credentials in `elk-wolfi/gitea_credentials.txt`. If missing, generates a 24-character cryptographically secure password and enforces **strict `0600` permissions**.
4. **Automated Sovereign TLS Certificate Deployment**: Generates private keys and signs Gitea certificates valid for 5 years (`ownca_not_after: "+1825d"`), deploying them to `~/.config/gitea/certs/` with correct `0600` key permissions.
5. **Rootless Pod & Volume Setup**: Dynamically creates the `gitea-stack` pod with ports `3000` (HTTPS) and `2222` (SSH), along with `gitea_db_data` and `gitea_app_data` volumes.
6. **Programmatic UI Installation Bypass**: Configures `GITEA__security__INSTALL_LOCK: "true"` and sets HTTPS root URLs automatically.
7. **User Systemd Integration**: Writes systemd unit files (`~/.config/systemd/user/`) and enables `pod-gitea-stack.service`.

### Execution Commands

To deploy locally on the active host:
```bash
ansible-playbook ansible/setup_gitea.yml
```

To run against a remote host inventory:
```bash
ansible-playbook -i inventory/hosts.yml ansible/setup_gitea.yml -e "target_hosts=gitea_production_nodes"
```

---

## 5. Post-Installation Account, Token & Repository Setup (CLI & API)

Once Gitea is active over HTTPS on port `3000`, perform initial administrative setup programmatically using `podman exec` (Gitea CLI) and `curl` (Gitea API).

### A. Create Admin Account via Gitea CLI

Execute the admin user creation command directly inside the container, supplying a strong operator-defined administrative secret (`<YOUR_SECURE_ADMIN_PASSWORD>`):

```bash
# Prompt for or set your secure admin password
read -sp "Enter Gitea Admin Password: " GITEA_ADMIN_PASS

podman exec -u git gitea-app gitea admin user create \
    --username dsom-admin \
    --password "${GITEA_ADMIN_PASS}" \
    --email admin@dsom.local \
    --admin
```

### B. Create Admin Access Token & Organization via API

Using `curl` over HTTPS with full Sovereign CA certificate verification:

```bash
# 1. Create Sudo Access Token for programmatic API access
curl -s --cacert ~/.config/gitea/certs/gitea.crt -X POST "https://10.17.250.28:3000/api/v1/users/dsom-admin/tokens" \
     -u "dsom-admin:${GITEA_ADMIN_PASS}" \
     -H "Content-Type: application/json" \
     -d '{"name": "setup-token", "scopes": ["all"]}' > token_resp.json

# Extract token for subsequent non-interactive requests
GITEA_TOKEN=$(grep -o '"sha1":"[^"]*' token_resp.json | cut -d'"' -f4)
rm -f token_resp.json

# 2. Create Organization using Access Token
curl -s --cacert ~/.config/gitea/certs/gitea.crt -X POST "https://10.17.250.28:3000/api/v1/orgs" \
     -H "Authorization: token ${GITEA_TOKEN}" \
     -H "Content-Type: application/json" \
     -d '{"username": "songketmailsdnbhd-group", "visibility": "public"}'

# 3. Create Repository under Organization
curl -s --cacert ~/.config/gitea/certs/gitea.crt -X POST "https://10.17.250.28:3000/api/v1/orgs/songketmailsdnbhd-group/repos" \
     -H "Authorization: token ${GITEA_TOKEN}" \
     -H "Content-Type: application/json" \
     -d '{"name": "um-elastic-soc", "private": false}'
```

### C. Register Host SSH Public Key (Port 2222)

To enable passwordless Git operations over SSH on port `2222`:

1. **Extract Host SSH Key**:
   ```bash
   cat ~/.ssh/id_dsom_ed25519.pub
   ```

2. **Upload Public Key to Gitea User via API**:
   ```bash
   cat <<EOF > ssh-key-payload.json
   {
     "title": "node-admin-key",
     "key": "$(cat ~/.ssh/id_dsom_ed25519.pub)",
     "read_only": false
   }
   EOF

   curl -s --cacert ~/.config/gitea/certs/gitea.crt -X POST "https://10.17.250.28:3000/api/v1/user/keys" \
        -H "Authorization: token ${GITEA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d @ssh-key-payload.json
   rm -f ssh-key-payload.json
   ```

3. **Register Gitea SSH Host Fingerprint**:
   ```bash
   ssh-keyscan -p 2222 10.17.250.28 >> ~/.ssh/known_hosts
   ```

---

## 6. Git Remote & Client Access (HTTPS & SSH)

### HTTPS Push/Pull Setup (Client Workstation / Windows / Linux)

To configure Git to push code to Sovereign Gitea over HTTPS securely:

1. **Install Certificate into Client Git / System Trust Store**:
   Ensure `gitea.crt` is added to your local system or Git trust store:
   ```bash
   git config --global http.sslCAInfo /path/to/sovereign-gitea-ca.crt
   ```

2. **Configure Remote & Push**:
   Use standard credential storage (or Git credential helper) rather than embedding passwords in git remote URLs:

   ```bash
   # Add remote using canonical host endpoint
   git remote add sovereign "https://10.17.250.28:3000/songketmailsdnbhd-group/um-elastic-soc.git"

   # Push main branch securely with full SSL verification enabled
   git push sovereign main
   ```

   *Note: Importing `gitea.crt` into your OS / Git Trusted Root Certification Authorities guarantees native TLS trust without bypassing SSL validation.*

### SSH Push/Pull Setup (Port 2222)

To push/pull using SSH without passwords:

```bash
# Add SSH remote pointing to mapped port 2222
git remote add gitea ssh://git@10.17.250.28:2222/songketmailsdnbhd-group/um-elastic-soc.git

# Fetch and Push
git fetch gitea
git push gitea main
```

---

## 7. Securing and Protecting Passwords in Git (Best Practices)

When developing playbooks or scripts, **hardcoded secrets inside Git repositories must be strictly avoided**. Implement these security mechanisms:

### Method 1: Ansible Vault (Encrypted Files in Git)
Encrypt secrets directly within your git directory:

1. **Create Encrypted Vault File**:
   ```bash
   ansible-vault create ansible/group_vars/vault_secrets.yml
   ```
2. **Declare Secrets**:
   ```yaml
   gitea_db_password: "MySuperSecretHardenedDbPassword_999!"
   ```
3. **Execute Playbook with Vault Password**:
   ```bash
   ansible-playbook ansible/setup_gitea.yml --ask-vault-pass
   # Or with password file excluded from Git:
   ansible-playbook ansible/setup_gitea.yml --vault-password-file ~/.gitea_vault_pass.txt
   ```

### Method 2: Runtime Environment Variables (Dynamic Ingestion)
Inject passwords dynamically at execution time using Ansible's environment plugin:

1. **Configure Variable Lookup in Playbook**:
   ```yaml
   gitea_db_password: "{{ lookup('ansible.builtin.env', 'GITEA_DB_PASSWORD') | default('', true) }}"
   ```
2. **Run Playbook with Dynamic Environment Variable**:
   ```bash
   GITEA_DB_PASSWORD="MyDynamicTerminalPassword_123!" ansible-playbook ansible/setup_gitea.yml
   ```

### Method 3: Local Repository Exclusions (`.gitignore`)
Ensure credential files are strictly excluded from Git tracking in `.gitignore`:

```git
# Prevent committing credentials and secrets
*temp_credentials.txt
*gitea_credentials.txt
*.env
*.vault
```

### Method 4: Automated Pre-commit Scanners
Detect credentials before committing:
```bash
# Run gitleaks locally to audit files
gitleaks detect -v
```

---

## 8. Maintenance & Operational Troubleshooting Commands

### Check Gitea Service Status
```bash
systemctl --user status pod-gitea-stack.service
```

### Inspect Container Logs
```bash
journalctl --user -u pod-gitea-stack.service -f
```

### Restart Gitea Service
```bash
systemctl --user restart pod-gitea-stack.service
```

### Troubleshooting: "Permission Denied" Reading `gitea.key`
If Gitea container fails to start due to `gitea.key` permission errors:
```bash
# Verify private key permissions are 0600 under host user session
chmod 0600 ~/.config/gitea/certs/gitea.key

# Reload systemd user daemon and restart service
systemctl --user daemon-reload
systemctl --user restart pod-gitea-stack.service
```

### Decommissioning & Cleanup
To completely remove the Gitea stack and persistent storage:

```bash
# Stop and disable systemd service
systemctl --user disable --now pod-gitea-stack.service
rm -f ~/.config/systemd/user/*gitea-stack*
systemctl --user daemon-reload

# Remove containers and pod
podman pod rm -f gitea-stack

# Remove persistent volumes
podman volume rm gitea_db_data gitea_app_data
```

---
*DSOM Engineering | Sovereign Gitea Deployment & Operations Guide v2.0*
{% endraw %}
