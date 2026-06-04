#!/usr/bin/env bash
# Pre-requisites:
#   - multipass
#
# Usage:
#   ./local-teardown.sh
# Example: 
#  ./local-teardown.sh

set -euo pipefail

VM_NAME_PREFIX="hanomi-"

# Find all VMs with the prefix
VM_NAMES=$(multipass list | grep "$VM_NAME_PREFIX" | awk '{print $1}')
if [ -z "$VM_NAMES" ]; then
    echo "No Hanomi VMs found."
    exit 0
fi
echo "Found VMs: $VM_NAMES"

# Stop and delete each VM
for VM_NAME in $VM_NAMES; do
    echo "Stopping $VM_NAME..."
    multipass stop $VM_NAME
    echo "Deleting $VM_NAME..."
    multipass delete $VM_NAME
    multipass purge
done

echo "All Hanomi VMs have been torn down."