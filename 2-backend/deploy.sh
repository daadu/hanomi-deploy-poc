####
## Deploy script for backend.
## 
## This script will be executed on the target VM to deploy the backend service, once the release artifacts are copied and extracted.
## Read the deploy flow documented in README.md for more information.
## 
## Usage:
##   ./deploy.sh <release-id>
####

set -euo pipefail

# config
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR=$(realpath "$SCRIPT_PATH/..")
SERVICE_RELEASES_DIR="${SERVICE_DIR}/releases"
SERVICE_NAME=$(basename "$SERVICE_DIR")
SERVICE_FULL_NAME="hanomi-${SERVICE_NAME}"

# arg parse
RELEASE_ID=${1:-}
if [ -z "$RELEASE_ID" ]; then
    echo "Error: Release ID is required"
    echo "Usage: $0 <release-id>"
    exit 1
fi

# helper functions
switch_and_release(){
     local rel_id="$1"
     ln -sfn "${SERVICE_RELEASES_DIR}/${rel_id}" "${CURRENT_RELEASE}"
     echo "Switched to release: $rel_id"

     echo "Restarting service..."
     sudo systemctl restart $SERVICE_FULL_NAME
     sleep 1
}

probe() {
    echo "Probing service..."
    sudo systemctl is-active --quiet "$SERVICE_FULL_NAME"

    curl -fsS http://127.0.0.1:8080/hello >/dev/null
}

#############################
# 1. Read current release id
#############################

CURRENT_RELEASE="${SERVICE_RELEASES_DIR}/current"
if [ -L "$CURRENT_RELEASE" ]; then
    PRE_DEPLOY_DIR=$(readlink "$CURRENT_RELEASE")
    PRE_DEPLOY_ID=$(basename "$PRE_DEPLOY_DIR")
else
    PRE_DEPLOY_DIR="Not found"
    PRE_DEPLOY_ID=""
fi
echo "Pre-deploy release id: $PRE_DEPLOY_ID [$PRE_DEPLOY_DIR]"

#############################
# 2. Pre-deploy steps (if any)
#############################

echo "TODO: we run migration here";

##################################################
# 3. Switch to new release
##################################################

echo "Switching to new release..."
switch_and_release "$RELEASE_ID"


##################################################
# 4. Probe: health check (exit if ok)
##################################################

if probe; then
    echo "==== Deployment successful ===="
    exit 0
fi


##########################################
# 5. Additional rollback steps (if needed)
##########################################

echo "TODO: rollback migration, to the schema that was active before the deployment"

##################################################
# 6. Revert to previous release
##################################################

if [ "$PRE_DEPLOY_ID" = "" ]; then
    echo "No previous release to revert to"
    exit 1
fi

echo "Reverting to previous release: $PRE_DEPLOY_ID"
switch_and_release "$PRE_DEPLOY_ID"


###############################################
# 7. Post-rollback probing
###############################################

if probe; then
    echo "==== Rollback successful ===="
    exit 0
fi

echo "==== ⚠️⚠️ CRITICAL: Rollback failed ⚠️⚠️ ===="
exit 1
