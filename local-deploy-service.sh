#!/usr/bin/env bash
# Pre-requisites:
#   - multipass
#   - local VM ready, bootstrapped using ./local-bootstrap.sh
#
# Usage:
#   ./local-deploy-service.sh <service>
# Example: 
#  ./local-deploy-service.sh frontend

set -euo pipefail

# Parse arguments
SERVICE="$1"

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

# Determine VM's ssh address
VM_HOST="hanomi-${SERVICE}"
VM_IP="$(multipass list | awk -v vm="$VM_HOST" '$1==vm {print $3}')"
if [ -z "$VM_IP" ]; then
    echo "ERROR: VM $VM_HOST not found."
    echo "Please run ./local-bootstrap.sh $SERVICE <ssh-key-path> first."
    exit 1
fi
VM_SSH_TARGET="hanomi@$VM_IP"
echo "Deploying service $SERVICE to $VM_SSH_TARGET..."
bash deploy-service.sh $SERVICE "$VM_SSH_TARGET"
