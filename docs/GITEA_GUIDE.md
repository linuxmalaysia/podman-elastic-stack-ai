{% raw %}
# Sovereign Gitea Deployment & Security Operations Guide

This guide details the deployment, configuration, maintenance, and secure operations of Gitea inside a rootless Podman stack.

Sovereign self-hosting means keeping code independent, secure, and resilient. This document covers both **Automated (Ansible Playbook)** and **Pure Command-Line** installation techniques, while deep-diving into safe password protection methodologies when utilizing Git-based workflows.

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

Our repository includes a robust, production-hardened, and fully idempotent Ansible playbook to deploy Gitea, configure its systemd integration, and securely handle runtime secrets.

For a comprehensive overview of our Ansible playbook files, variables, and individual execution techniques, please refer to the main [Playbooks Guide](PLAYBOOKS.md).

### Playbook Tasks Performed
1. **OS Detection & Package Setup**: Detects if your system is Debian/Ubuntu or RPM-based (CentOS, RedHat, AlmaLinux, Rocky) and installs `podman` and `podman-compose` automatically if missing.
2. **User Linger Control**: Automatically invokes `loginctl enable-linger` for the playbook execution user.
3. **Automated Password Management**: Securely checks if a password file already exists. If not, it generates a high-entropy, cryptographically secure 24-character random password, saving it with **strict `0600` permissions** to prevent any unauthorized host-level access.
4. **Rootless Pod Space & Volumes**: Creates a rootless network namespace (pod) and isolated named storage volumes.
5. **Postgres and Gitea Container Deployments**: Starts the containers securely within the rootless pod using secure runtime configurations.
6. **Systemd Unit File Generation & Activation**: Generates user-level systemd unit files on-the-fly (`~/.config/systemd/user/`) from the active pod state and enables them via systemd user manager.

### Running the Playbook

To run the playbook against localhost:
```bash
ansible-playbook ansible/setup_gitea.yml
```

To run against a remote inventory host:
```bash
ansible-playbook -i inventory/hosts.yml ansible/setup_gitea.yml -e "target_hosts=gitea_production_nodes"
```

---

## 3. Option B: Pure Command-Line Deployment (Manual)

If you prefer to set up the sovereign Gitea stack manually using direct command-line execution, follow these steps:

### A. Create the Pod
The pod binds the services into a shared network namespace, exposing port `3000` for HTTP and port `2222` for SSH.
```bash
podman pod create \
    --name gitea-stack \
    --publish 3000:3000 \
    --publish 2222:22
```

### B. Create Storage Volumes

Isolate Postgres and Gitea application storage into Podman-managed volumes.

```bash
podman volume create gitea_db_data
podman volume create gitea_app_data
```

### C. Set Up Environment Secrets File

To ensure `podman generate systemd --new` does not embed plaintext database and application passwords inside generated systemd unit files, we store the passwords in a protected `0600` environment file on the host.

Create the file `gitea.env` (e.g. in your secure configuration directory):

```bash
cat <<EOF > gitea.env
POSTGRES_PASSWORD=YourHardenedPasswordHere_99X
GITEA__database__PASSWD=YourHardenedPasswordHere_99X
EOF
chmod 0600 gitea.env
```

### D. Deploy Postgres Database

Run the Postgres container inside the pod, referencing the secure environment file:

```bash
podman run --detach \
    --name gitea-db \
    --pod gitea-stack \
    --restart always \
    --env POSTGRES_USER=gitea \
    --env-file gitea.env \
    --env POSTGRES_DB=gitea \
    --volume gitea_db_data:/var/lib/postgresql/data:Z \
    docker.io/library/postgres:15-alpine
```

### E. Deploy Gitea Application

Run the Gitea container inside the pod, referencing the secure environment file, setting the domain and SSH port config properly:

```bash
podman run --detach \
    --name gitea-app \
    --pod gitea-stack \
    --restart always \
    --env GITEA__database__DB_TYPE=postgres \
    --env GITEA__database__HOST=localhost:5432 \
    --env GITEA__database__NAME=gitea \
    --env GITEA__database__USER=gitea \
    --env-file gitea.env \
    --env GITEA__server__PROTOCOL=http \
    --env GITEA__server__DOMAIN=192.168.100.207 \
    --env GITEA__server__ROOT_URL=http://192.168.100.207:3000/ \
    --env GITEA__server__HTTP_PORT=3000 \
    --env GITEA__server__SSH_PORT=2222 \
    --volume gitea_app_data:/data:Z \
    --volume /etc/timezone:/etc/timezone:ro \
    --volume /etc/localtime:/etc/localtime:ro \
    docker.io/gitea/gitea:1.26.1
```

### F. Systemd Integration

Generate user systemd files to manage the rootless stack via standard systemctl tools.

```bash
# Create directory structure
mkdir -p ~/.config/systemd/user/
cd ~/.config/systemd/user/

# Generate files from current running containers
podman generate systemd --name gitea-stack --files --new

# Reload user-level systemd daemon and enable service
systemctl --user daemon-reload
systemctl --user enable --now pod-gitea-stack.service
```

---

## 4. Securing and Protecting Passwords in Git (Best Practices)

When developing playbooks or scripts, **hardcoded secrets inside Git repositories must be strictly avoided**. Here are the industry-standard solutions to protect database and application credentials:

### Method 1: Ansible Vault (Encrypted Files in Git)
Ansible Vault allows you to encrypt files, variables, or entire playbooks directly inside your git directory. Only users with the vault decryption key can read or execute them.

1. **Create an Encrypted Variable File**:
   ```bash
   ansible-vault create ansible/group_vars/vault_secrets.yml
   ```
2. **Add Your Secrets**:
   Inside the editor, declare your variables directly matching those consumed by the playbook:
   ```yaml
   gitea_db_password: "MySuperSecretHardenedDbPassword_999!"
   ```
3. **Run Playbooks with Decryption Key**:
   ```bash
   ansible-playbook ansible/setup_gitea.yml --ask-vault-pass
   # Or using a secure local password file (excluded from Git):
   ansible-playbook ansible/setup_gitea.yml --vault-password-file ~/.gitea_vault_pass.txt
   ```

### Method 2: Runtime Environment Variables (Dynamic Ingestion)
Instead of committing passwords, inject them dynamically from the active runtime environment using the Ansible environment lookup plugin:

1. **Configure Variable Lookup in the Playbook**:
   ```yaml
   gitea_db_password: "{{ lookup('ansible.builtin.env', 'GITEA_DB_PASSWORD') | default('', true) }}"
   ```
2. **Pass Password dynamically when executing**:
   ```bash
   GITEA_DB_PASSWORD="MyDynamicTerminalPassword_123!" ansible-playbook ansible/setup_gitea.yml
   ```

### Method 3: Strictly Configured Local Exclusions (`.gitignore`)
Always enforce local credential files to be excluded from being tracked by git. This prevents manual copy-paste errors or accidental file additions (`git add .`) from leaking secrets to remote repositories.

In your root `.gitignore`, ensure you have:
```git
# Prevent committing credentials and secrets
*temp_credentials.txt
*gitea_credentials.txt
*.env
*.vault
```

### Method 4: Automated Pre-commit Scanners & CI/CD Guardrails
Prevent human errors before a commit can be created or pushed to origin:
1. **Gitleaks**: Run a local pre-commit hook to detect high-entropy string patterns, passwords, and API keys:
   ```bash
   # Run gitleaks locally to check files
   gitleaks detect -v
   ```
2. **GitHub Advanced Security (Secret Scanning)**: Enable automated secret scanning in your repository settings to block pushes containing credentials or revoke them immediately upon discovery.

---

## 5. Maintenance & Operation Commands

### Check Gitea Stack Status
Verify that the master systemd unit and corresponding containers are active:
```bash
systemctl --user status pod-gitea-stack.service
```

### View Live Service Logs
```bash
journalctl --user -u pod-gitea-stack.service -f
```

### Gracefully Restart the Stack
```bash
systemctl --user restart pod-gitea-stack.service
```

### Destroying the Stack
To clean up and remove the services and volumes permanently:
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
{% endraw %}
