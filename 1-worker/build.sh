#!/usr/bin/env bash
####
## Build script for frontend module
## 
## Prerequisites:
## - Node.js 16.8.0 or higher
## - Linux environment (CI-runner)
####

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_DIR="$SCRIPT_DIR/code"
BUILD_DIR="$SCRIPT_DIR/build"

echo "No build required for worker."
echo "Copying source code to build directory..."
# ensure no uncommitted changes
if [ -n "$(git -C "$CODE_DIR" status --porcelain)" ]; then
    echo "ERROR: Repository contains uncommitted changes."
    echo "Commit or stash changes before building."
    exit 1
fi
# remove existing build artifacts + scaffold build dirs
rm -rf "$BUILD_DIR/*"
mkdir -p "$BUILD_DIR/.next"
# copy all files tracked by git
git -C "$CODE_DIR" checkout-index \
    --all \
    --force \
    --prefix="$BUILD_DIR/"
echo "Worker source code copied successfully."

