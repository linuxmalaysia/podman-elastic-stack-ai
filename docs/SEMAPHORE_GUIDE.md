{% raw %}
# Sovereign SemaphoreUI Deployment & Security Operations Guide

This guide details the deployment, configuration, maintenance, and secure operations of SemaphoreUI (an open-source alternative to Ansible Tower) running inside a rootless Podman stack.

<!-- markdownlint-disable-file MD041 -->

Sovereign self-hosting means keeping automation pipelines independent, secure, and resilient. This document covers both **Automated (Ansible Playbook)** and **Pure Command-Line** installation techniques, details Gitea trust integration, and outlines safe secret protection methodologies when utilizing Git-based workflows.

---

## 1. Prerequisites

Before running any commands or playbooks, make sure the following host configurations are present.

### Clone the Repository

To obtain the Ansible playbooks, setup scripts, and configurations, clone the git repository to your local system and navigate to the project directory:

```bash
# Clone the repository
git clone https://github.com/linuxmalaysia/podman-elastic-stack-ai.git

# Navigate into the project directory
cd podman-elastic-stack-ai
```

For more details on cloning and initial repository setups, see the [Git Repository guide in INSTALL.md](INSTALL.md#git-repository).

### Enable User Linger
Rootless containers run in user space. By default, user processes are terminated when your active SSH or terminal session closes. Enabling linger allows rootless container managers and systemd user services to run continuously in the background:
```bash
sudo loginctl enable-linger $(whoami)
```

### Verify Podman & Podman Compose
Confirm that your host has Podman 4+ or 5+ and Podman Compose installed:
```bash
podman --version
podman-compose --version
```

---

## 2. Option A: Automated Ansible Deployment (Recommended)

Our repository includes a robust, production-hardened, and fully idempotent Ansible playbook to deploy SemaphoreUI as a Podman Quadlet-native service, configure Gitea CA trust, and securely handle runtime secrets.

For a comprehensive overview of our Ansible playbook files, variables, and individual execution techniques, please refer to the main [Playbooks Guide](PLAYBOOKS.md).

### Playbook Tasks Performed
1. **OS Detection & Package Setup**: Detects if your system is Debian/Ubuntu or RPM-based (CentOS, RedHat, AlmaLinux, Rocky) and installs `podman` and `podman-compose` automatically if missing.
2. **User Linger Control**: Automatically invokes `loginctl enable-linger` for the playbook execution user.
3. **Automated Password Management**: Securely checks if a password file already exists (`elk-wolfi/semaphore_credentials.txt`). If not, it generates high-entropy, cryptographically secure random passwords and a 32-byte Base64-encoded Semaphore access key, saving them with **strict `0600` permissions** to prevent any unauthorized host-level access.
4. **TLS Configuration & CA Trust**:
   - Automatically generates a 10-year self-signed SSL certificate (`semaphore.crt` and `semaphore.key`) and places it in `~/.config/containers/semaphoreui/certs/`.
   - Automatically installs this certificate directly into the Host's OS root trust store (`/etc/ssl/certs/ca-certificates.crt` on Ubuntu, or `/etc/pki/ca-trust/source/anchors/` on AlmaLinux/RPM).
   - Natively mounts this host-side trust bundle directly into the Semaphore container so that the underlying git libraries (`go-git`) can securely communicate with Gitea or other internal servers over TLS.
5. **Systemd Kube Quadlet Generation**: Creates user-level systemd unit files on-the-fly (`~/.config/containers/systemd/semaphore-stack.kube` and `semaphore-stack.yaml`) from the active configuration.
6. **Systemd Service Activation**: Reloads the user systemd daemon and starts the `semaphore-stack.service` which handles the deployment.

### Variables Configuration
Before deploying, you can update variables in `inventory/group_vars/all.yml` or pass them dynamically:
```yaml
semaphore_db_password: "YourSecureDatabasePassword"
semaphore_admin_password: "YourSecureAdminPassword"
semaphore_access_key: "O+lQUe0zYznywVp/GEpSREX9NlT/0tNQnFZNAhFD7Vg=" # 32-byte valid Base64 string
```

### Running the Playbook

To run the playbook against localhost:
```bash
ansible-playbook ansible/setup_semaphore.yml
```

To run against a remote inventory host:
```bash
ansible-playbook -i inventory/hosts.yml ansible/setup_semaphore.yml -e "target_hosts=production_nodes"
```

---

## 3. Option B: Pure Command-Line Deployment (Manual)

If you prefer to set up the sovereign SemaphoreUI stack manually using direct command-line execution and Kube Quadlets, follow these steps:

### A. Create Directories and Generate Certificates
Create the configuration directories and generate a self-signed certificate for local TLS communication:
```bash
mkdir -p ~/.config/containers/semaphoreui/certs
mkdir -p ~/.config/containers/systemd

# Generate self-signed certificate (10-year)
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout ~/.config/containers/semaphoreui/certs/semaphore.key \
  -out ~/.config/containers/semaphoreui/certs/semaphore.crt \
  -sha256 -days 3650 \
  -subj "/C=MY/ST=Kuala Lumpur/L=Kuala Lumpur/O=Sovereign/OU=IT/CN=localhost"
```

### B. Install Certificate in Host Trust Store
To allow git libraries within the container to clone from local servers over TLS, make the certificate trusted by the host:
- **For Debian/Ubuntu**:
  ```bash
  sudo cp ~/.config/containers/semaphoreui/certs/semaphore.crt /usr/local/share/ca-certificates/semaphore.crt
  sudo update-ca-certificates
  ```
- **For RedHat/CentOS/AlmaLinux**:
  ```bash
  sudo cp ~/.config/containers/semaphoreui/certs/semaphore.crt /etc/pki/ca-trust/source/anchors/semaphore.crt
  sudo update-ca-trust
  ```

### C. Create the Quadlet Kube File
Create `~/.config/containers/systemd/semaphore-stack.kube` on the host:
```ini
[Unit]
Description=Sovereign Semaphore UI Stack (Quadlet Kube)

[Kube]
Yaml=semaphore-stack.yaml

[Install]
WantedBy=default.target
```

### D. Create the Kubernetes Pod Manifest
Create `~/.config/containers/systemd/semaphore-stack.yaml` on the host. Substitute your passwords and CA bundle paths where appropriate (e.g. `/etc/ssl/certs/ca-certificates.crt` on Ubuntu, or `/etc/pki/tls/certs/ca-bundle.crt` on AlmaLinux):
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: semaphore-stack
spec:
  containers:
    - name: semaphore-db
      image: docker.io/library/mysql:8.0
      env:
        - name: MYSQL_RANDOM_ROOT_PASSWORD
          value: "yes"
        - name: MYSQL_DATABASE
          value: semaphore
        - name: MYSQL_USER
          value: semaphore
        - name: MYSQL_PASSWORD
          value: "YourSecureDatabasePassword"
        - name: TZ
          value: "Asia/Kuala_Lumpur"
      volumeMounts:
        - name: semaphore-mysql
          mountPath: /var/lib/mysql
    - name: semaphore-app
      image: docker.io/semaphoreui/semaphore:latest
      env:
        - name: SEMAPHORE_DB_USER
          value: semaphore
        - name: SEMAPHORE_DB_PASS
          value: "YourSecureDatabasePassword"
        - name: SEMAPHORE_DB_HOST
          value: localhost
        - name: SEMAPHORE_DB_PORT
          value: "3306"
        - name: SEMAPHORE_DB_DIALECT
          value: mysql
        - name: SEMAPHORE_DB
          value: semaphore
        - name: SEMAPHORE_PLAYBOOK_PATH
          value: /tmp/semaphore/
        - name: SEMAPHORE_ADMIN_PASSWORD
          value: "YourSecureAdminPassword"
        - name: SEMAPHORE_ADMIN_NAME
          value: admin
        - name: SEMAPHORE_ADMIN_EMAIL
          value: admin@localhost
        - name: SEMAPHORE_ADMIN
          value: admin
        - name: SEMAPHORE_ACCESS_KEY_ENCRYPTION
          value: "O+lQUe0zYznywVp/GEpSREX9NlT/0tNQnFZNAhFD7Vg=" # exactly 32-byte Base64 key
        - name: SEMAPHORE_LDAP_ACTIVATED
          value: "no"
        - name: SEMAPHORE_TLS_ENABLED
          value: "True"
        - name: SEMAPHORE_TLS_CERT_FILE
          value: /etc/semaphore/certs/semaphore.crt
        - name: SEMAPHORE_TLS_KEY_FILE
          value: /etc/semaphore/certs/semaphore.key
        - name: TZ
          value: "Asia/Kuala_Lumpur"
      volumeMounts:
        - name: semaphore-certs
          mountPath: /etc/semaphore/certs
        - name: host-ca-certs
          mountPath: /etc/ssl/certs/ca-certificates.crt
          readOnly: true
  volumes:
    - name: semaphore-mysql
      persistentVolumeClaim:
        claimName: semaphore-mysql-pvc
    - name: semaphore-certs
      hostPath:
        path: /home/your_username/.config/containers/semaphoreui/certs
        type: Directory
    - name: host-ca-certs
      hostPath:
        path: /etc/ssl/certs/ca-certificates.crt
        type: File
```

### E. Load and Start via User Systemd
Activate the Quadlet configuration:
```bash
systemctl --user daemon-reload
systemctl --user enable --now semaphore-stack.service
```

---

## 4. Securing and Protecting Passwords in Git (Best Practices)

When developing playbooks or tasks, **hardcoded secrets inside Git repositories must be strictly avoided**. Here are the industry-standard solutions to protect database and application credentials:

### Method 1: Ansible Vault (Encrypted Files in Git)
Ansible Vault allows you to encrypt files, variables, or entire playbooks directly inside your git directory.

1. **Create an Encrypted Variable File**:
   ```bash
   ansible-vault create ansible/group_vars/vault_secrets.yml
   ```
2. **Add Your Secrets**:
   ```yaml
   semaphore_db_password: "MySuperSecretHardenedDbPassword_999!"
   semaphore_admin_password: "MySuperSecretAdminPassword_123!"
   semaphore_access_key: "O+lQUe0zYznywVp/GEpSREX9NlT/0tNQnFZNAhFD7Vg="
   ```
3. **Run Playbooks with Decryption Key**:
   ```bash
   ansible-playbook ansible/setup_semaphore.yml --ask-vault-pass
   ```

### Method 2: Runtime Environment Variables (Dynamic Ingestion)
Instead of committing passwords, inject them dynamically from the active runtime environment using the Ansible environment lookup:

1. **Configure Variable Lookup in the Playbook**:
   ```yaml
   semaphore_db_password: "{{ lookup('ansible.builtin.env', 'SEMAPHORE_DB_PASSWORD') | default('', true) }}"
   ```
2. **Pass Password dynamically when executing**:
   ```bash
   SEMAPHORE_DB_PASSWORD="MyDynamicTerminalPassword_123!" ansible-playbook ansible/setup_semaphore.yml
   ```

### Method 3: Strictly Configured Local Exclusions (`.gitignore`)
Always enforce local credential files to be excluded from being tracked by git. In your root `.gitignore`, ensure you have:
```git
# Prevent committing credentials and secrets
*temp_credentials.txt
*semaphore_credentials.txt
*.env
*.vault
```

---

## 5. Maintenance & Operation Commands

### Check Semaphore Stack Status
Verify that the master systemd unit and corresponding containers are active:
```bash
systemctl --user status semaphore-stack.service
```

### View Live Service Logs
```bash
journalctl --user -u semaphore-stack.service -f
```

### Gracefully Restart the Stack
```bash
systemctl --user restart semaphore-stack.service
```

### Destroying the Stack
To clean up and remove the services and volumes permanently:
```bash
# Stop and disable systemd service
systemctl --user disable --now semaphore-stack.service
rm -f ~/.config/containers/systemd/semaphore-stack*
systemctl --user daemon-reload

# Remove persistent volumes
podman volume rm semaphore-mysql-pvc
```

---

## 6. Web GUI Configuration (GitOps Workflow)

SemaphoreUI is designed as a native GitOps CI/CD engine. Rather than mounting local files into the container, it clones your repository and dynamically executes playbooks.

### 1. Initial Login
Access the web dashboard at `https://<jumphost-ip>:3001` (Accept the self-signed certificate warning). Log in using the credentials defined in the Ansible variables:
*   **Username**: `admin`
*   **Password**: Your configured `semaphore_admin_password`

### 2. Key Store
Semaphore runs isolated within Podman and cannot read `~/.ssh/id_rsa` on the host. You must provide it with credentials to interact with your nodes and Gitea.
1. Navigate to **Key Store** -> **New Key** -> **SSH Key**. Paste your host's private SSH key (e.g. `dsom-admin` private SSH key). This key will be used by Semaphore to execute remote Ansible commands across the cluster via SSH.
2. Navigate to **Key Store** -> **New Key** -> **Login with password**.
   * **Login**: Provide your Gitea username (e.g. `dsom-admin`). *Note: This field cannot be empty!*
   * **Password**: Paste your Gitea Personal Access Token (PAT).
   * This key will be used to authenticate Git HTTPS clones.

### 3. Repository Setup
Connect Semaphore to your internal Gitea server.
1. Navigate to **Repositories** -> **New Repository**.
2. **Repository URL**: `https://<gitea-ip>:3000/songketmailsdnbhd-group/um-elastic-soc.git`
3. **Branch**: `main`
4. **Access Key**: Select the Gitea PAT key you created in the Key Store.

### 4. Inventory Setup
Instead of maintaining a separate static inventory, instruct Semaphore to read your Git repository's inventory file.
1. Navigate to **Inventory** -> **New Inventory**.
2. **Type**: `File`
3. **Path**: `inventory/hosts.yml`

### 5. Environments (Privilege Escalation)
If your playbook requires root access (`become: yes`), Semaphore actively blocks privilege escalation for security reasons unless an explicit Environment is attached.
1. Navigate to **Environments** -> **New Environment** (In older versions, this is called Variable Groups).
2. Name it (e.g., `Production Environment`).
3. Under **Extra variables (JSON)**, define your escalation parameters:
   ```json
   {
     "ansible_become": true,
     "ansible_become_method": "sudo",
     "ansible_become_user": "root",
     "ansible_become_pass": "your-sudo-password"
   }
   ```
   *Note: If all nodes in your inventory support passwordless sudo, you can omit the `ansible_become_pass` key.*
4. Click Save.

### 6. Task Templates (Playbook Execution)
Task Templates are the "Run Buttons" for your automation.
1. Navigate to **Task Templates** -> **New Template**.
2. **Playbook Filename**: Provide the relative path (e.g., `playbooks/rolling-reboot-kibana.yml`).
3. **Inventory & Repository**: Select the ones created in the previous steps.
4. **Variable Groups**: Select the `Production Environment` created above to authorize privilege escalation.
5. **Advanced Options (CLI args)**: You can inject variables directly into the Ansible run exactly as you would on the CLI (e.g., `-e bypass_green_check=true`).

Once saved, click **Run** to execute the playbook and monitor real-time logs directly in the browser.
{% endraw %}
