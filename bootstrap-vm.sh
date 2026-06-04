#!/usr/bin/env bash
# Run bootstrap script on the target VM.
# 
# Prerequisites:
# - ssh access to the target VM
#
# Usage:
#   ./bootstrap-vm.sh <service> <ssh-target>
# Example: 
#  ./bootstrap-vm.sh frontend hanomi@192.168.1.100

set -euo pipefail

# Parse arguments
SERVICE="${1:-}"
SSH_TARGET="${2:-}"

# Determine service directory and check if has required scripts
if [[ "$SERVICE" =~ ^[0-9]+- ]]; then
    SERVICE_DIR="$SERVICE"
else
    SERVICE_DIR="$(find . -maxdepth 1 -type d -name "*-$SERVICE" | head -n1)"
fi
[ -n "$SERVICE_DIR" ] || {
    echo "Unknown service: $SERVICE"
    exit 1
}
if [ ! -d "$SERVICE_DIR" ]; then
    echo "Service directory not found: $SERVICE_DIR"
    exit 1
fi
if [ -f "$SERVICE_DIR/bootstrap.sh" ]; then
    VM_OS="linux"
    BOOTSTRAP_SCRIPT="$SERVICE_DIR/bootstrap.sh"
elif [ -f "$SERVICE_DIR/bootstrap.ps1" ]; then
    VM_OS="windows"
    BOOTSTRAP_SCRIPT="$SERVICE_DIR/bootstrap.ps1"
else
    echo "ERROR: No bootstrap script found in service directory: $SERVICE_DIR"
    exit 1
fi

# Validate SSH target
if [[ ! "$SSH_TARGET" =~ ^[^@]+@[^@]+$ ]]; then
    echo "ERROR: Invalid SSH target format. Expected <user>@<host> as second argument"
    exit 1
fi

# Copy bootstrap script to VM
echo "Copying bootstrap script to VM..."
if [ "$VM_OS" = "windows" ]; then
    TMP_DIR="C:\\tmp"
    VM_BOOTSTRAP_SCRIPT="$TMP_DIR\\bootstrap.ps1"    
else
    TMP_DIR="/tmp"
    VM_BOOTSTRAP_SCRIPT="$TMP_DIR/bootstrap.sh"
fi
scp -o StrictHostKeyChecking=no "$BOOTSTRAP_SCRIPT" "$SSH_TARGET":$VM_BOOTSTRAP_SCRIPT


# Run bootstrap script (via SSH )
echo "Running bootstrap script..." 
if [ "$VM_OS" = "windows" ]; then
    ssh -o StrictHostKeyChecking=no "$SSH_TARGET" "powershell -ExecutionPolicy Bypass -File $VM_BOOTSTRAP_SCRIPT"
else
    ssh -o StrictHostKeyChecking=no  "$SSH_TARGET" "bash $VM_BOOTSTRAP_SCRIPT"
fi
echo "==== Bootstrap script executed successfully ===="

# Enter via SSH to validate
echo "================================================"
echo "Validate the bootstrap script execution manually once, by sshing into the VM with following:"
echo "ssh -o StrictHostKeyChecking=no $SSH_TARGET"
