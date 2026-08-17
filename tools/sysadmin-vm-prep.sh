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
read -p "👤 Enter Initial SSH Username (e.g., admin, root, user): " REMOTE_USER
if [ -z "$REMOTE_USER" ]; then
    echo -e "${RED}❌ Error: Remote user is required.${NC}"
    exit 1
fi

# Probe for existing configuration (if dsom-admin access exists)
EXISTING_ROOT=""
echo -e "${YELLOW}🔍 Probing for existing configuration...${NC}"
if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=30 "dsom-admin@$TARGET_HOST" "[ -f /etc/um-elastic-soc.conf ]" 2>/dev/null; then
    PROBED_ROOT=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no "dsom-admin@$TARGET_HOST" "grep '^dsom_root=' /etc/um-elastic-soc.conf | cut -d= -f2" 2>/dev/null)
    if [[ "$PROBED_ROOT" =~ ^/.* ]]; then
        EXISTING_ROOT="$PROBED_ROOT"
        echo -e "${GREEN}[OK] Found existing config: $EXISTING_ROOT${NC}"
    fi
fi

DEFAULT_ROOT="${EXISTING_ROOT:-/opt/dsom-persistence}"
read -p "📂 Enter Persistence Root Path [$DEFAULT_ROOT]: " USER_INPUT_ROOT
DSOM_ROOT=${USER_INPUT_ROOT:-$DEFAULT_ROOT}

# New dsom-admin password with local hashing
echo -e "\n${CYAN}Set Password for 'dsom-admin' (for manual/emergency access)${NC}"
read -s -p "🔑 New Password: " SOVEREIGN_PASS
echo ""
read -s -p "🔑 Confirm Password: " SOVEREIGN_PASS_CONFIRM
echo ""

if [ "$SOVEREIGN_PASS" != "$SOVEREIGN_PASS_CONFIRM" ]; then
    echo -e "${RED}❌ Error: Passwords do not match.${NC}"
    exit 1
fi

SOVEREIGN_HASHED_PASS=""
if [ -n "$SOVEREIGN_PASS" ]; then
    echo -ne "${YELLOW}[VAULT] Generating SHA-512 hash locally...${NC}"
    SOVEREIGN_HASHED_PASS=$(echo "$SOVEREIGN_PASS" | openssl passwd -6 -stdin)
    echo -e "${GREEN} Done.${NC}"
fi

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
    -e "target_host=$TARGET_HOST" \
    -e "ansible_user=$REMOTE_USER" \
    -e "sovereign_password='$SOVEREIGN_HASHED_PASS'" \
    -e "dsom_root=$DSOM_ROOT" \
    -e "ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o ControlMaster=no'" \
    -k -K -v

if [ $? -ne 0 ]; then
    echo -e "\n${RED}[ERROR] Phase 1 (Bootstrap) failed. Aborting.${NC}"
    exit 1
fi

# Step 1.5: Sync SSH Key Names for default SSH clients
echo -e "\n${YELLOW}Step 1.5: Syncing SSH Keys...${NC}"
if [ -f ~/.ssh/id_dsom_ed25519 ]; then
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        echo -e "${CYAN}Copying id_dsom_ed25519 to standard id_ed25519 for default client compatibility...${NC}"
        cp ~/.ssh/id_dsom_ed25519 ~/.ssh/id_ed25519
        cp ~/.ssh/id_dsom_ed25519.pub ~/.ssh/id_ed25519.pub
        chmod 600 ~/.ssh/id_ed25519
        chmod 644 ~/.ssh/id_ed25519.pub
    else
        echo -e "${GREEN}Default id_ed25519 already exists. Skipping copy.${NC}"
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
    -e "ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o PreferredAuthentications=publickey,password'" \
    -v

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}[SUCCESS] Node $TARGET_HOST is now compliant.${NC}"
    echo -e "${CYAN}Verification Dashboard (as dsom-admin):${NC}"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes dsom-admin@$TARGET_HOST "printf \"  - OS: %s\n  - User: %s\n  - Root: $DSOM_ROOT\n  - NTP (Chrony): %s\n  - Lynis Score: %s\n\" \"\$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d \\\")\" \"\$(id dsom-admin)\" \"\$(chronyc tracking | grep 'System time' | xargs || echo 'NOT_SYNCED')\" \"\$(grep '^lynis_score=' /etc/um-elastic-soc.conf | cut -d= -f2 | grep . || echo 'N/A')\"" 2>/dev/null
else
    echo -e "\n${RED}[ERROR] Phase 2 (Fabric) failed for $TARGET_HOST.${NC}"
    exit 1
fi

echo -e "${CYAN}==================================================${NC}"
