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
GOOS=linux GOARCH=amd64 go build -C "$CODE_DIR" -o "$BUILD_DIR/backend"
echo "Backend built successfully"