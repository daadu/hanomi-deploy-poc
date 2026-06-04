#!/usr/bin/env bash
####
## Build script for backend module
## 
## Prerequisites:
## - Go 1.21 or higher
## - Linux environment (CI-runner)
####

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_DIR="$SCRIPT_DIR/code"
BUILD_DIR="$SCRIPT_DIR/build"

echo "Building backend..."
# remove existing build artifacts + scaffold build dirs
rm -rf "$BUILD_DIR/*"
mkdir -p "$BUILD_DIR"
# build backend
BUILD_BIN_PATH="$BUILD_DIR/backend"
# if hostmachine is macos, then is not prod but local development.
# for macos+apple silicon, the mutlipass VM runs on arm64 architecture, therefore we keep the machine's architecture
if [[ "$(uname -s)" == "Darwin" ]]; then
    GOARCH="$(go env GOARCH)"
else
    GOARCH="amd64" # for prod always amd64
fi
GOOS=linux GOARCH=$GOARCH go build -C "$CODE_DIR" -o "$BUILD_BIN_PATH"
chmod +x "$BUILD_BIN_PATH"
echo "Backend built successfully at $BUILD_BIN_PATH"