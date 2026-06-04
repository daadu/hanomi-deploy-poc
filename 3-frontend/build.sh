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

echo "Building frontend..."
npm ci --prefix "$CODE_DIR"
npm run build --prefix "$CODE_DIR"
echo "Frontend built successfully"

echo "Copying build artifacts..."
# ensure that the .next/standalone/server.js file exists
if [ ! -f "$CODE_DIR/.next/standalone/server.js" ]; then
    echo "ERROR: Next.js standalone server not found. Set \"output: 'standalone'\" in next.config.js for production builds."
    exit 1
fi
# remove existing build artifacts + scaffold build dirs
rm -rf "$BUILD_DIR/*"
mkdir -p "$BUILD_DIR/.next"
# copy build artifacts
cp -r "$CODE_DIR/.next/standalone/"* "$BUILD_DIR/"
cp -r "$CODE_DIR/.next/static" "$BUILD_DIR/.next/static"
cp -r "$CODE_DIR/public" "$BUILD_DIR/public/"

# FIXME: the "dummy submodule repo" we use is not ignoring .next directory, therefore will remove it manually to avoid having dirty git status
rm -rf "$CODE_DIR/.next"
echo "Build artifacts copied successfully"