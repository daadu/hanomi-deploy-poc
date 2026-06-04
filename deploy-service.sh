#!/usr/bin/env bash
# Deploy a service to the target VM.
#
# This script always try to deploy.
# 
# Prerequisites:
# - ssh access to the target VM
# - git
# - tar
#
# Usage:
#   ./deploy-service.sh <service> <ssh-target> <?ssh-port:default=22>
# Example: 
#  ./deploy-service.sh frontend hanomi@192.168.1.100

set -euo pipefail

# Parse arguments
SERVICE="${1:-}"
SSH_TARGET="${2:-}"
SSH_PORT="${3:-22}"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
BUILD_SCRIPT="$SERVICE_DIR/build.sh"
if [ ! -f "$BUILD_SCRIPT" ]; then
    echo "Build script not found in service directory: $SERVICE_DIR"
    exit 1
fi
CODE_REPO="$SERVICE_DIR/code"
if [ ! -d "$CODE_REPO" ]; then
    echo "Code repository not found in service directory: $SERVICE_DIR"
    exit 1
fi
if [ -f "$SERVICE_DIR/deploy.sh" ]; then
    VM_OS="linux"
    DEPLOY_SCRIPT="$SERVICE_DIR/deploy.sh"
elif [ -f "$SERVICE_DIR/deploy.ps1" ]; then
    VM_OS="windows"
    DEPLOY_SCRIPT="$SERVICE_DIR/deploy.ps1"
else
    echo "ERROR: No deploy script found"
    exit 1
fi

# Validate SSH target
if [[ ! "$SSH_TARGET" =~ ^[^@]+@[^@]+$ ]]; then
    echo "ERROR: Invalid SSH target format. Expected <user>@<host> as second argument"
    exit 1
fi
# check if SSH connection works
ssh \
  -o BatchMode=yes \
  -o ConnectTimeout=5 \
  -p "$SSH_PORT" \
  "$SSH_TARGET" \
  exit


###########################
# 1. Determine release-id
###########################
# format: <YYYY-MM-DD-HHMMSS>-<git-commit-hash><?-dirty>
# dirty is true if there are uncommitted changes (in deploy or code repo)
# NOTE: the git commmit hash should be of the "code repo"
RELEASE_AT="$(date +%Y-%m-%d-%H%M%S)"
CODE_COMMIT_HASH="$(cd "$CODE_REPO" && git rev-parse --short HEAD)"
DEPLOY_COMMIT_HASH="$(cd "$SCRIPT_PATH" && git rev-parse --short HEAD)"
DIRTY=""
if [ -n "$(cd "$CODE_REPO" && git status --porcelain)" ]; then
    DIRTY="${DIRTY}+dirty_code"
elif [ -n "$(cd "$SCRIPT_PATH" && git status --porcelain)" ]; then
    DIRTY="${DIRTY}+dirty_deploy"
fi
RELEASE_ID="${RELEASE_AT}-${CODE_COMMIT_HASH}${DIRTY}"
echo "Release ID: $RELEASE_ID"

##################
# 2. Build service
##################
echo "Building service..."
# export release id as environment variable, incase build needs to "stamp it"
export HANOMI_RELEASE_ID="$RELEASE_ID"
bash "$BUILD_SCRIPT"
BUILD_DIR="$SERVICE_DIR/build"
[ -d "$BUILD_DIR" ] || {
    echo "ERROR: Build directory not found: $BUILD_DIR"
    exit 1
}
[ "$(find "$BUILD_DIR" -mindepth 1 | wc -l)" -gt 0 ] || {
    echo "ERROR: Build directory is empty: $BUILD_DIR"
    exit 1
}
echo "Following files in build directory [$BUILD_DIR]:"
ls -alh "$BUILD_DIR"

############################################
# 3. Create metadata.json in build dir
############################################
echo "Creating metadata.json in build directory..."
METADATA_FILE="$BUILD_DIR/metadata.json"
cat > "$METADATA_FILE" << EOF
{
  "service": "$SERVICE",
  "release_id": "$RELEASE_ID",
  "release_at": "$RELEASE_AT",
  "code_hash": "$CODE_COMMIT_HASH",
  "deploy_hash": "$DEPLOY_COMMIT_HASH",
  "dirty": "$DIRTY"
}
EOF
echo "Build metadata created: $METADATA_FILE ..."
cat "$METADATA_FILE"


##################
# 4. Archive build
##################
echo "Archiving build..."
BUILD_ARCHIVE="$SERVICE_DIR/build-$RELEASE_ID.tar.gz"
tar -czf "$BUILD_ARCHIVE" -C "$BUILD_DIR" .
echo "Build archive created: $BUILD_ARCHIVE"


#################################
# 5. Transfer build archive to VM
#################################
echo "Transferring build archive to VM..."
if [ "$VM_OS" = "windows" ]; then
    TMP_DIR="C:\\tmp"
    ARCHIVE_DST="$TMP_DIR\\build-$SERVICE-$RELEASE_ID.tar.gz"
else
    TMP_DIR="/tmp"
    ARCHIVE_DST="$TMP_DIR/build-$SERVICE-$RELEASE_ID.tar.gz"
fi
scp -P "$SSH_PORT" "$BUILD_ARCHIVE" "$SSH_TARGET:$ARCHIVE_DST"
echo "Build archive transferred to VM at: $ARCHIVE_DST"


#################################
# 6. Extract build archive on VM
#################################
echo "Extracting build archive on VM..."
if [ "$VM_OS" = "windows" ]; then
    VM_HOME="C:\Users\hanomi"
    VM_SVC_DIR="$VM_HOME\\hanomi\\$SERVICE"
    RELEASE_DIR="$VM_SVC_DIR\\releases\\$RELEASE_ID"
else
    VM_HOME="/home/hanomi"
    VM_SVC_DIR="$VM_HOME/hanomi/$SERVICE"
    RELEASE_DIR="$VM_SVC_DIR/releases/$RELEASE_ID"
fi
ssh "$SSH_TARGET" "mkdir -p '$RELEASE_DIR' && tar --warning=no-unknown-keyword -xzf '$ARCHIVE_DST' -C '$RELEASE_DIR'"
echo "Build archive extracted on VM at: $RELEASE_DIR"


#################################
# 7. Transfer deploy script to VM
#################################
echo "Transferring deploy script to VM..."
if [ "$VM_OS" = "windows" ]; then
    VM_SCRIPT_DIR="$VM_SVC_DIR\\scripts\\"
else
    VM_SCRIPT_DIR="$VM_SVC_DIR/scripts/"
fi
scp -P "$SSH_PORT" "$DEPLOY_SCRIPT" "$SSH_TARGET:$VM_SCRIPT_DIR"
echo "Deploy script transferred to VM at: $VM_SCRIPT_DIR"


#################################
# 8. Execute deploy script on VM
#################################
echo "Executing deploy script on VM..."
if [ "$VM_OS" = "windows" ]; then
    ssh -p "$SSH_PORT" "$SSH_TARGET" "powershell -ExecutionPolicy Bypass -File $VM_SCRIPT_DIR/deploy.ps1 $RELEASE_ID"
else
    ssh -p "$SSH_PORT" "$SSH_TARGET" "bash $VM_SCRIPT_DIR/deploy.sh $RELEASE_ID"
fi
echo "Deploy script executed on VM"


# DONE
echo "==== DEPLOYMENT COMPLETE ===="    