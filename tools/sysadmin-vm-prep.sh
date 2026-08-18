#!/bin/bash
# ==============================================================================
# [DEPLOY] Remote VM Provisioner (v1.0)
#
# Usage: bash tools/sysadmin-vm-prep.sh <IP_OR_HOSTNAME>
# Description: Bootstraps a raw VM into a DSOM/Podman-compliant node.
# Handles Ubuntu, Debian, RHEL, AlmaLinux, Rocky, and Oracle Linux.
# ==============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TARGET_HOST=$1

if [ -z "$TARGET_HOST" ]; then
    echo -e "${RED}❌ Error: No target host provided.${NC}"
    echo -e "${YELLOW}Usage: bash tools/sysadmin-vm-prep.sh <ip-address-or-hostname>${NC}"
    exit 1
fi

echo -e "${CYAN}==================================================${NC}"
echo -e "${CYAN}    PROVISIONER: BOOTSTRAPPING REMOTE VM          ${NC}"
echo -e "${CYAN}    Target: $TARGET_HOST${NC}"
echo -e "${CYAN}==================================================${NC}"

# Interactive Credential Collection
read -r -p "👤 Enter Initial SSH Username (e.g., admin, root, user): " REMOTE_USER
if [ -z "$REMOTE_USER" ]; then
    echo -e "${RED}❌ Error: Remote user is required.${NC}"
    exit 1
fi

# Probe for existing configuration (if dsom-admin access exists)
EXISTING_ROOT=""
echo -e "${YELLOW}🔍 Probing for existing configuration...${NC}"
if ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts -o ConnectTimeout=30 "dsom-admin@$TARGET_HOST" "[ -f /etc/um-elastic-soc.conf ]" 2>/dev/null; then
    PROBED_ROOT=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts "dsom-admin@$TARGET_HOST" "grep '^dsom_root=' /etc/um-elastic-soc.conf | cut -d= -f2" 2>/dev/null)
    if [[ "$PROBED_ROOT" =~ ^/.* ]]; then
        EXISTING_ROOT="$PROBED_ROOT"
        echo -e "${GREEN}[OK] Found existing config: $EXISTING_ROOT${NC}"
    fi
fi

DEFAULT_ROOT="${EXISTING_ROOT:-/opt/dsom-persistence}"
read -r -p "📂 Enter Persistence Root Path [$DEFAULT_ROOT]: " USER_INPUT_ROOT
DSOM_ROOT=${USER_INPUT_ROOT:-$DEFAULT_ROOT}

# New dsom-admin password with local hashing
echo -e "\n${CYAN}Set Password for 'dsom-admin' (for manual/emergency access)${NC}"
read -r -s -p "🔑 New Password: " SOVEREIGN_PASS
echo ""
read -r -s -p "🔑 Confirm Password: " SOVEREIGN_PASS_CONFIRM
echo ""

if [ "$SOVEREIGN_PASS" != "$SOVEREIGN_PASS_CONFIRM" ]; then
    echo -e "${RED}❌ Error: Passwords do not match.${NC}"
    exit 1
fi

SOVEREIGN_HASHED_PASS=""
if [ -n "$SOVEREIGN_PASS" ]; then
    echo -ne "${YELLOW}[VAULT] Generating SHA-512 hash locally...${NC}"
    SOVEREIGN_HASHED_PASS=$(echo "$SOVEREIGN_PASS" | openssl passwd -6 -stdin)
    if [ -z "$SOVEREIGN_HASHED_PASS" ]; then
        echo -e "${RED}\n❌ Error: Failed to generate password hash.${NC}"
        exit 1
    fi
    echo -e "${GREEN} Done.${NC}"
fi

# Write password hash securely to temporary vars file
TMP_VARS_FILE=$(mktemp /tmp/dsom_bootstrap_vars_XXXXXX.yml)
chmod 0600 "$TMP_VARS_FILE"
trap 'rm -f "$TMP_VARS_FILE"' EXIT

cat > "$TMP_VARS_FILE" <<EOF
sovereign_password: "${SOVEREIGN_HASHED_PASS}"
EOF

# Set Local Ansible Connection if target is localhost
if [ "$TARGET_HOST" == "127.0.0.1" ] || [ "$TARGET_HOST" == "localhost" ]; then
    LOCAL_FLAG="-c local"
else
    LOCAL_FLAG=""
fi

# Step 1: Bootstrap Identity
echo -e "\n${YELLOW}Step 1: Establishing Identity (as $REMOTE_USER)...${NC}"
echo -e "${YELLOW}Note: You will be prompted for SSH and Sudo passwords for '$REMOTE_USER' now.${NC}"

# Override restrictive ansible.cfg ssh_args that enforce publickey
export ANSIBLE_SSH_ARGS="-o ControlMaster=auto -o ControlPersist=60s -o PreferredAuthentications=password,publickey"

ansible-playbook -i "$TARGET_HOST," \
    playbooks/bootstrap-node.yml \
    $LOCAL_FLAG \
    -u "$REMOTE_USER" \
    --tags bootstrap \
    -e "@$TMP_VARS_FILE" \
    -e "target_host=$TARGET_HOST" \
    -e "ansible_user=$REMOTE_USER" \
    -e "dsom_root=$DSOM_ROOT" \
    -e "ansible_ssh_extra_args='-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts -o PreferredAuthentications=password -o ControlMaster=no'" \
    -k -K -v

if [ $? -ne 0 ]; then
    echo -e "\n${RED}[ERROR] Phase 1 (Bootstrap) failed. Aborting.${NC}"
    exit 1
fi

# Step 1.5: Configure SSH Client Entry
echo -e "\n${YELLOW}Step 1.5: Configuring SSH Client Host Entry...${NC}"
mkdir -p ~/.ssh && chmod 0700 ~/.ssh
SSH_CONFIG=~/.ssh/config
if [ -f ~/.ssh/id_dsom_ed25519 ]; then
    if ! grep -q "Host $TARGET_HOST" "$SSH_CONFIG" 2>/dev/null; then
        cat >> "$SSH_CONFIG" <<EOF

Host $TARGET_HOST
    HostName $TARGET_HOST
    User dsom-admin
    IdentityFile ~/.ssh/id_dsom_ed25519
    StrictHostKeyChecking accept-new
EOF
        chmod 0600 "$SSH_CONFIG"
        echo -e "${GREEN}[OK] Added Host entry for $TARGET_HOST to ~/.ssh/config${NC}"
    fi
fi

# Step 2: OS Configuration
echo -e "\n${CYAN}Step 2: Transitioning to Host Configuration (as dsom-admin)...${NC}"
echo -e "${YELLOW}Transitioning to key-based access...${NC}"

ansible-playbook -i "$TARGET_HOST," \
    playbooks/bootstrap-node.yml \
    $LOCAL_FLAG \
    -u "dsom-admin" \
    --private-key ~/.ssh/id_dsom_ed25519 \
    --tags fabric \
    -e "target_host=$TARGET_HOST" \
    -e "dsom_root=$DSOM_ROOT" \
    -e "ansible_ssh_extra_args='-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts -o PreferredAuthentications=publickey,password'" \
    -v

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}[SUCCESS] Node $TARGET_HOST is now compliant.${NC}"
    echo -e "${CYAN}Verification Dashboard (as dsom-admin):${NC}"
    ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts -o BatchMode=yes "dsom-admin@$TARGET_HOST" "printf '  - OS: %s\n  - User: %s\n  - Root: %s\n  - NTP (Chrony): %s\n  - Lynis Score: %s\n' \"\$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d \\\")\" \"\$(id dsom-admin)\" \"$DSOM_ROOT\" \"\$(chronyc tracking | grep 'System time' | xargs || echo 'NOT_SYNCED')\" \"\$(grep '^lynis_score=' /etc/um-elastic-soc.conf | cut -d= -f2 | grep . || echo 'N/A')\"" 2>/dev/null
else
    echo -e "\n${RED}[ERROR] Phase 2 (Fabric) failed for $TARGET_HOST.${NC}"
    exit 1
fi

echo -e "${CYAN}==================================================${NC}"
