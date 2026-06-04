#!/usr/bin/env bash
# Pre-requisites:
#   - multipass
#
# Usage:
#   ./local-bootstrap.sh <service> <ssh-key-path>
# Example: 
#  ./local-bootstrap.sh frontend ~/.ssh/id_ed25519

set -euo pipefail

# Parse arguments
SERVICE="${1:-}"
SSH_KEY_PATH="${2:-}"

# Determine service directory
if [[ "$SERVICE" =~ ^[0-9]+- ]]; then
    SERVICE_DIR="$SERVICE"
else
    SERVICE_DIR="$(find . -maxdepth 1 -type d -name "*-$SERVICE" | head -n1)"
fi
[ -n "$SERVICE_DIR" ] || {
    echo "Unknown service: $SERVICE"
    exit 1
}

# Determine the OS based on bootstrap file extension
if [ -f "$SERVICE_DIR/bootstrap.sh" ]; then
    VM_OS="linux"
    BOOTSTRAP_SCRIPT="$SERVICE_DIR/bootstrap.sh"
elif [ -f "$SERVICE_DIR/bootstrap.ps1" ]; then
    VM_OS="windows"
    BOOTSTRAP_SCRIPT="$SERVICE_DIR/bootstrap.ps1"
    # currently only linux is supported
    echo "ERROR: Windows bootstrap not supported yet"
    exit 1
else
    echo "ERROR: No bootstrap script found"
    exit 1
fi

# Validate SSH key
if [ -z "$SSH_KEY_PATH" ]; then 
    echo "ERROR: SSH key path is required, pass it as second argument" 
    exit 1 
fi 
if [ ! -f "$SSH_KEY_PATH" ] || [ ! -f "$SSH_KEY_PATH.pub" ]; then 
    echo "ERROR: SSH keys ($SSH_KEY_PATH or $SSH_KEY_PATH.pub) do not exist" 
    exit 1 
fi 
SSH_KEY_PATH="$(realpath "$SSH_KEY_PATH")"

# Create VM
echo "Creating VM..."
VM_NAME="hanomi-${SERVICE}"
# -- remove old (if exists)
multipass delete "$VM_NAME" >/dev/null 2>&1 || true
multipass purge >/dev/null 2>&1 || true
# --- launch fresh instance
multipass launch 24.04 \
    --name "$VM_NAME" \
    --cpus 2 \
    --memory 2G \
    --disk 10G
multipass exec "$VM_NAME" -- cloud-init status --wait # wait for cloud-init to complete
# --- create hanomi user (if not exists)
multipass exec "$VM_NAME" -- sudo bash -c '
id -u hanomi >/dev/null 2>&1 || useradd -m -s /bin/bash hanomi
usermod -aG sudo hanomi

# no passowrd required to run sudo commands
echo "hanomi ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/hanomi
chmod 440 /etc/sudoers.d/hanomi
'
# --- add ssh key as authorized
multipass transfer "$SSH_KEY_PATH.pub" "$VM_NAME":/tmp/id_ed25519.pub
multipass exec "$VM_NAME" -- sudo bash -c '
mkdir -p /home/hanomi/.ssh
chmod 700 /home/hanomi/.ssh
cp /tmp/id_ed25519.pub /home/hanomi/.ssh/authorized_keys
chmod 600 /home/hanomi/.ssh/authorized_keys
chown -R hanomi:hanomi /home/hanomi/.ssh
'

# Figure VM address
VM_IP="$(multipass list | awk -v vm="$VM_NAME" '$1==vm {print $3}')"
echo "VM IP: $VM_IP"
SSH_TARGET="hanomi@$VM_IP"

# Run bootstrap script against vm
bash ./bootstrap-vm.sh "$SERVICE" "$SSH_TARGET"
